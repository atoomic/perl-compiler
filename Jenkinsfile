#!groovy
@Library('cpanel-pipeline-library@master') _
node('docker && jenkins-user') {
    environment.check()

    def cpVersion = '11.74'
    def JOBS=24
    def perlVersion = '528'
    def productionBranch = 'bc528' // controls if we push to the Registry
    def TESTS="t/*.t t/testsuite/C-COMPILED/*/*.t"  // full run
    //def TESTS="t/*.t" // short version

    Map scmVars
    def testResults
    def registry_info = registry.getInfo()

    try {
        def email
        // EMAIL is defined at the folder level via the Folder Properties Plugin
        withFolderProperties {
            if (env.EMAIL == null) {
                error "EMAIL must be defined as a Folder Property"
            }
            email = env.EMAIL
        }

        notify.emailAtEnd([to:email]) {
            stage('Setup') {
                scmVars = checkout scm
                notifyHipchat(currentBuild.result, scmVars, testResults)

                // implied 'INPROGRESS' to Bitbucket
                notifyBitbucket commitSha1: scmVars.GIT_COMMIT
            }

            def bc_image
            stage('Docker image build') {
                docker.withRegistry(registry_info.url, registry_info.credentialsId) {
                    bc_image = docker.build("pax/bc-node:${cpVersion}", "--pull --build-arg REGISTRY_HOST=${registry_info.host} --build-arg CPVERSION=${cpVersion} .")
                }
            }

            bc_image.inside {
                stage('Setup sandbox') {
                    // give it more time...
                    timeout(time: 5, unit: 'MINUTES') { sh 'sudo ./pre-setup.sh' }
                    // sh 'sudo ./pre-setup.sh'
                }

                stage('Makefile.PL') { sh makefileCommands() }

                // pek: the chown is so that the cleanWs() later doesn't have problems removing
                //   artifacts (that are created during the 'sudo make install')
                stage('make install') {
                    String commands = """
                        sudo make -j${JOBS} install
                        sudo chown -R jenkins:jenkins .
                    """
                    sh commands
                }

                stage('Unit tests') {
                    String commands = """
                        # smoke compiled tests and t/*.t
                        set +x
                        ## run as root, so we do not skip tests that check \$>
                        sudo bash -lc "PATH=/usr/local/cpanel/3rdparty/perl/${perlVersion}/bin:\$PATH /usr/local/cpanel/3rdparty/bin/prove -v -wm -j${JOBS} --formatter TAP::Formatter::JUnit ${TESTS}" >junit.xml || /bin/true
                        git diff t/testsuite/C-COMPILED/known_errors.txt > known_errors_delta.txt
                    """

                    timeout(time: 30, unit: 'MINUTES') { sh commands }
                }

                stage('Process results') {
                    archiveArtifacts artifacts: 'junit.xml'
                    archiveArtifacts artifacts: 'known_errors_delta.txt'

                    // pek: hudson.tasks.junit.TestResultSummary (failCount skipCount passCount totalCount)
                    testResults = junit testResults: 'junit.xml', keepLongStdio: false
                    if (_testsFailed(testResults)) {
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
            // push self image to Registry ONLY IF: the work succeeds, and this is one of the fancy production branches
            if (currentBuild.result != 'UNSTABLE' && env.BRANCH_NAME == productionBranch) {
                stage('Docker push to internal Registry') {
                    docker.withRegistry(registry_info.url, registry_info.credentialsId) {
                        bc_image.push()
                    }
                }
            }
        }
    }
    finally {
        // scmVars will be null if we bomb out before the checkout (e.g. failure to set EMAIL in
        //   the folder properties)
        if (scmVars != null) {
            notifyBitbucket commitSha1: scmVars.GIT_COMMIT
            notifyHipchat(currentBuild.result, scmVars, testResults)
        }
        cleanWs()
    }
}

def notifyHipchat(String status, Map scmVars, def testResults) {
    def hipchatRoom = 'Busy Camels'
    if (!environment.isProduction()) {
        hipchatRoom = 'Brian Baxter'
    }
    String reposURL = util.escapeHTML(bitbucket.getWebURL(scmVars.GIT_URL))
    String shortSHA = scmVars.GIT_COMMIT.substring(0,10)

    String extra_info = ''
    String color
    String icon
    if (null == status) {
        status = 'Pending'
        icon = '&#x023F1;'  // stopwatch
        color = 'GRAY'
    } else if (('FAILURE' == status) || (null == testResults)) {
        icon = '&#x1F6D1'  // stop sign
        color = 'RED'
    }
    else if (_testsFailed(testResults)) {
        icon = '&#x1f44e;'  // thumbs down
        color = 'YELLOW'
        extra_info = """<br>${testResults.failCount} failed. ${testResults.passCount} passed. ${testResults.totalCount} total."""
    } else {
        icon = '&#x2705;' // check box
        color = 'GREEN'
    }

    String message = """$icon $status &raquo; <a href="${reposURL}/browse">${ util.escapeHTML(JOB_NAME) }</a> &raquo; ${ util.escapeHTML(BUILD_DISPLAY_NAME) } for
(<a href="${reposURL}/commits/${scmVars.GIT_COMMIT}">$shortSHA</a>) &rarr; <a href="${ util.escapeHTML(BUILD_URL) }">View build</a>
$extra_info"""

    hipchatSend([
        color: color,
        failOnError: true,
        message: message,
        notify: true,
        room: hipchatRoom,
        sendAs: 'Jenkins',
        textFormat: false,
        v2enabled: false])
}

def _testsFailed(testResults) {
    return testResults.failCount > 0
}

// Emacs' "balanced parenthesis" does not like the dollar square bracket variable
String makefileCommands() {
    return '''
        set +x
        /usr/local/cpanel/3rdparty/bin/perl -E 'say "# using cpanel perl version ", $]'
        rm -rf t/testsuite/t/extra/check-PL_strtab*
        /usr/local/cpanel/3rdparty/bin/perl Makefile.PL installdirs=vendor
        git checkout t
    '''
}
