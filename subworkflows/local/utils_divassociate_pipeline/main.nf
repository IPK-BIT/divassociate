include { view_vcf } from '../../../modules/local/bcftools'
include { UTILS_NEXTFLOW_PIPELINE } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALIZE THE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow PIPELINE_INITIALIZATION {
    take:
    version             // boolean: Display version and exit
    _validate_params     // boolean: Boolean whether to validate parameters against the schema at runtime
    _monochrome_logs     // boolean: Do not use coloured log outputs
    _nextflow_cli_args   // array: List of positional nextflow CLI args
    outdir              // string: The output directory where the results will be saved
    vcf                 // string: Path to input genotypes
    _phenotypes          // string: Path to input phenotypes

    main:

    _ch_versions = Channel.empty()

    /*
    Print version and exit if required and dump parameters to JSON file
    */
    
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    /*
    Custom validation for pipeline parameters
    */
    validateInputParams(vcf)
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow PIPELINE_COMPLETION {
    take:
    email           // string: email address
    email_on_fail   // string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          // path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        // string: hook URL for notifications
    main:
    summary_params = null //paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
def validateInputParams(_vcf) {
    return true
}

def completionEmail(_summary_params, email, email_on_fail, plaintext_email, outdir, monochrome_logs=true) {

    // Set up the e-mail variables
    def subject = "[${workflow.manifest.name}] Successful: ${workflow.runName}"
    if (!workflow.success) {
        subject = "[${workflow.manifest.name}] FAILED: ${workflow.runName}"
    }

    // def summary = [:]
    // summary_params
    //     .keySet()
    //     .sort()
    //     .each { group ->
    //         summary << summary_params[group]
    //     }

    def misc_fields = [:]
    misc_fields['Date Started']              = workflow.start
    misc_fields['Date Completed']            = workflow.complete
    misc_fields['Pipeline script file path'] = workflow.scriptFile
    misc_fields['Pipeline script hash ID']   = workflow.scriptId
    if (workflow.repository) {
        misc_fields['Pipeline repository Git URL']    = workflow.repository
    }
    if (workflow.commitId) {
        misc_fields['Pipeline repository Git Commit'] = workflow.commitId
    }
    if (workflow.revision) {
        misc_fields['Pipeline Git branch/tag']        = workflow.revision
    }
    misc_fields['Nextflow Version']          = workflow.nextflow.version
    misc_fields['Nextflow Build']            = workflow.nextflow.build
    misc_fields['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    def email_fields = [:]
    email_fields['version']      = getWorkflowVersion()
    email_fields['runName']      = workflow.runName
    email_fields['success']      = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration']     = workflow.duration
    email_fields['exitStatus']   = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport']  = (workflow.errorReport ?: 'None')
    email_fields['commandLine']  = workflow.commandLine
    email_fields['projectDir']   = workflow.projectDir
    // email_fields['summary']      = summary << misc_fields

    // On success try attach the multiqc report
    // def mqc_report = attachMultiqcReport(multiqc_report)

    // Check if we are only sending emails on failure
    def email_address = email
    if (!email && email_on_fail && !workflow.success) {
        email_address = email_on_fail
    }

    // Render the TXT template
    def engine       = new groovy.text.GStringTemplateEngine()
    def tf           = new File("${workflow.projectDir}/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt    = txt_template.toString()

    // Render the HTML template
    def hf            = new File("${workflow.projectDir}/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html    = html_template.toString()

    // Render the sendmail template
    def max_multiqc_email_size = (params.containsKey('max_multiqc_email_size') ? params.max_multiqc_email_size : 0) as MemoryUnit
    def smail_fields           = [email: email_address, subject: subject, email_txt: email_txt, email_html: email_html, projectDir: "${workflow.projectDir}", mqcMaxSize: max_multiqc_email_size.toBytes()]
    def sf                     = new File("${workflow.projectDir}/assets/sendmail_template.txt")
    def sendmail_template      = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html          = sendmail_template.toString()

    // Send the HTML e-mail
    def colors = logColours(monochrome_logs) as Map
    if (email_address) {
        try {
            if (plaintext_email) {
new org.codehaus.groovy.GroovyException('Send plaintext e-mail, not HTML')            }
            // Try to send HTML e-mail using sendmail
            def sendmail_tf = new File(workflow.launchDir.toString(), ".sendmail_tmp.html")
            sendmail_tf.withWriter { w -> w << sendmail_html }
            ['sendmail', '-t'].execute() << sendmail_html
            log.info("-${colors.purple}[${workflow.manifest.name}]${colors.green} Sent summary e-mail to ${email_address} (sendmail)-")
        }
        catch (Exception _all) {
            // Catch failures and try with plaintext
            def mail_cmd = ['mail', '-s', subject, '--content-type=text/html', email_address]
            mail_cmd.execute() << email_html
            log.info("-${colors.purple}[${workflow.manifest.name}]${colors.green} Sent summary e-mail to ${email_address} (mail)-")
        }
    }

    // Write summary e-mail HTML to a file
    def output_hf = new File(workflow.launchDir.toString(), ".pipeline_report.html")
    output_hf.withWriter { w -> w << email_html }
    nextflow.extension.FilesEx.copyTo(output_hf.toPath(), "${outdir}/pipeline_info/pipeline_report.html")
    output_hf.delete()

    // Write summary e-mail TXT to a file
    def output_tf = new File(workflow.launchDir.toString(), ".pipeline_report.txt")
    output_tf.withWriter { w -> w << email_txt }
    nextflow.extension.FilesEx.copyTo(output_tf.toPath(), "${outdir}/pipeline_info/pipeline_report.txt")
    output_tf.delete()
}

def completionSummary(monochrome_logs=true) {
    def colors = logColours(monochrome_logs) as Map
    if (workflow.success) {
        if (workflow.stats.ignoredCount == 0) {
            log.info("-${colors.purple}[${workflow.manifest.name}]${colors.green} Pipeline completed successfully${colors.reset}-")
        }
        else {
            log.info("-${colors.purple}[${workflow.manifest.name}]${colors.yellow} Pipeline completed successfully, but with errored process(es) ${colors.reset}-")
        }
    }
    else {
        log.info("-${colors.purple}[${workflow.manifest.name}]${colors.red} Pipeline completed with errors${colors.reset}-")
    }
}

def getWorkflowVersion() {
    def version_string = "" as String
    if (workflow.manifest.version) {
        def prefix_v = workflow.manifest.version[0] != 'v' ? 'v' : ''
        version_string += "${prefix_v}${workflow.manifest.version}"
    }

    if (workflow.commitId) {
        def git_shortsha = workflow.commitId.substring(0, 7)
        version_string += "-g${git_shortsha}"
    }

    return version_string
}

def logColours(monochrome_logs=true) {
    def colorcodes = [:] as Map

    // Reset / Meta
    colorcodes['reset']      = monochrome_logs ? '' : "\033[0m"
    colorcodes['bold']       = monochrome_logs ? '' : "\033[1m"
    colorcodes['dim']        = monochrome_logs ? '' : "\033[2m"
    colorcodes['underlined'] = monochrome_logs ? '' : "\033[4m"
    colorcodes['blink']      = monochrome_logs ? '' : "\033[5m"
    colorcodes['reverse']    = monochrome_logs ? '' : "\033[7m"
    colorcodes['hidden']     = monochrome_logs ? '' : "\033[8m"

    // Regular Colors
    colorcodes['black']  = monochrome_logs ? '' : "\033[0;30m"
    colorcodes['red']    = monochrome_logs ? '' : "\033[0;31m"
    colorcodes['green']  = monochrome_logs ? '' : "\033[0;32m"
    colorcodes['yellow'] = monochrome_logs ? '' : "\033[0;33m"
    colorcodes['blue']   = monochrome_logs ? '' : "\033[0;34m"
    colorcodes['purple'] = monochrome_logs ? '' : "\033[0;35m"
    colorcodes['cyan']   = monochrome_logs ? '' : "\033[0;36m"
    colorcodes['white']  = monochrome_logs ? '' : "\033[0;37m"

    // Bold
    colorcodes['bblack']  = monochrome_logs ? '' : "\033[1;30m"
    colorcodes['bred']    = monochrome_logs ? '' : "\033[1;31m"
    colorcodes['bgreen']  = monochrome_logs ? '' : "\033[1;32m"
    colorcodes['byellow'] = monochrome_logs ? '' : "\033[1;33m"
    colorcodes['bblue']   = monochrome_logs ? '' : "\033[1;34m"
    colorcodes['bpurple'] = monochrome_logs ? '' : "\033[1;35m"
    colorcodes['bcyan']   = monochrome_logs ? '' : "\033[1;36m"
    colorcodes['bwhite']  = monochrome_logs ? '' : "\033[1;37m"

    // Underline
    colorcodes['ublack']  = monochrome_logs ? '' : "\033[4;30m"
    colorcodes['ured']    = monochrome_logs ? '' : "\033[4;31m"
    colorcodes['ugreen']  = monochrome_logs ? '' : "\033[4;32m"
    colorcodes['uyellow'] = monochrome_logs ? '' : "\033[4;33m"
    colorcodes['ublue']   = monochrome_logs ? '' : "\033[4;34m"
    colorcodes['upurple'] = monochrome_logs ? '' : "\033[4;35m"
    colorcodes['ucyan']   = monochrome_logs ? '' : "\033[4;36m"
    colorcodes['uwhite']  = monochrome_logs ? '' : "\033[4;37m"

    // High Intensity
    colorcodes['iblack']  = monochrome_logs ? '' : "\033[0;90m"
    colorcodes['ired']    = monochrome_logs ? '' : "\033[0;91m"
    colorcodes['igreen']  = monochrome_logs ? '' : "\033[0;92m"
    colorcodes['iyellow'] = monochrome_logs ? '' : "\033[0;93m"
    colorcodes['iblue']   = monochrome_logs ? '' : "\033[0;94m"
    colorcodes['ipurple'] = monochrome_logs ? '' : "\033[0;95m"
    colorcodes['icyan']   = monochrome_logs ? '' : "\033[0;96m"
    colorcodes['iwhite']  = monochrome_logs ? '' : "\033[0;97m"

    // Bold High Intensity
    colorcodes['biblack']  = monochrome_logs ? '' : "\033[1;90m"
    colorcodes['bired']    = monochrome_logs ? '' : "\033[1;91m"
    colorcodes['bigreen']  = monochrome_logs ? '' : "\033[1;92m"
    colorcodes['biyellow'] = monochrome_logs ? '' : "\033[1;93m"
    colorcodes['biblue']   = monochrome_logs ? '' : "\033[1;94m"
    colorcodes['bipurple'] = monochrome_logs ? '' : "\033[1;95m"
    colorcodes['bicyan']   = monochrome_logs ? '' : "\033[1;96m"
    colorcodes['biwhite']  = monochrome_logs ? '' : "\033[1;97m"

    return colorcodes
}

def imNotification(summary_params, hook_url) {
    def summary = [:]
    summary_params
        .keySet()
        .sort()
        .each { group ->
            summary << summary_params[group]
        }

    def misc_fields = [:]
    misc_fields['start']          = workflow.start
    misc_fields['complete']       = workflow.complete
    misc_fields['scriptfile']     = workflow.scriptFile
    misc_fields['scriptid']       = workflow.scriptId
    if (workflow.repository) {
        misc_fields['repository'] = workflow.repository
    }
    if (workflow.commitId) {
        misc_fields['commitid']   = workflow.commitId
    }
    if (workflow.revision) {
        misc_fields['revision']   = workflow.revision
    }
    misc_fields['nxf_version']    = workflow.nextflow.version
    misc_fields['nxf_build']      = workflow.nextflow.build
    misc_fields['nxf_timestamp']  = workflow.nextflow.timestamp

    def msg_fields = [:]
    msg_fields['version']      = getWorkflowVersion()
    msg_fields['runName']      = workflow.runName
    msg_fields['success']      = workflow.success
    msg_fields['dateComplete'] = workflow.complete
    msg_fields['duration']     = workflow.duration
    msg_fields['exitStatus']   = workflow.exitStatus
    msg_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    msg_fields['errorReport']  = (workflow.errorReport ?: 'None')
    msg_fields['commandLine']  = workflow.commandLine.replaceFirst(/ +--hook_url +[^ ]+/, "")
    msg_fields['projectDir']   = workflow.projectDir
    msg_fields['summary']      = summary << misc_fields

    // Render the JSON template
    def engine       = new groovy.text.GStringTemplateEngine()
    // Different JSON depending on the service provider
    // Defaults to "Adaptive Cards" (https://adaptivecards.io), except Slack which has its own format
    def json_path     = hook_url.contains("hooks.slack.com") ? "slackreport.json" : "adaptivecard.json"
    def hf            = new File("${workflow.projectDir}/assets/${json_path}")
    def json_template = engine.createTemplate(hf).make(msg_fields)
    def json_message  = json_template.toString()

    // POST
    def post = new URL(hook_url).openConnection()
    post.setRequestMethod("POST")
    post.setDoOutput(true)
    post.setRequestProperty("Content-Type", "application/json")
    post.getOutputStream().write(json_message.getBytes("UTF-8"))
    def postRC = post.getResponseCode()
    if (!postRC.equals(200)) {
        log.warn(post.getErrorStream().getText())
    }
}