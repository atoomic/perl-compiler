#!groovy
@Library('cpanel-pipeline-library@master') _
node('docker && jenkins-user') {
    environment.check()

    // ensure these values are in sync with the Dockerfile
    def cpVersion = '11.74'
    def perlVersion = '526'
    def TESTS="t/*.t t/testsuite/C-COMPILED/*/*.t"  // full run

    Map scmVars
    def testResults

    try {
        notify.emailAtEnd {
            docker.image("pax/bc-node:${cpVersion}").inside {
                stage('Setup') {
                    scmVars = checkout scm
                    notifyHipchat(currentBuild.result, scmVars, testResults)

                    // implied 'INPROGRESS' to Bitbucket
                    notifyBitbucket commitSha1: scmVars.GIT_COMMIT
                }

                stage('Makefile.PL') { sh makefileCommands() }

                // pek: the chown is so that the cleanWs() later doesn't have problems removing
                //   artifacts (that are created during the 'sudo make install')
                stage('make install') {
                    String commands = '''
                        sudo make -j24 install
                        sudo chown -R jenkins:jenkins .
                    '''
                    sh commands
                }

                stage('Unit tests') {
                    String commands = """
                        # smoke compiled tests and t/*.t
                        set +x
                        ## run as root, so we do not skip tests that check \$>
                        sudo bash -lc "PATH=/usr/local/cpanel/3rdparty/perl/${perlVersion}/bin:\$PATH prove -v -wm -j24 --formatter TAP::Formatter::JUnit ${TESTS}" >junit.xml || /bin/true
                    """

                    timeout(time: 30, unit: 'MINUTES') { sh commands }
                }

                stage('Process results') {
                    archiveArtifacts artifacts: 'junit.xml'

                    // pek: hudson.tasks.junit.TestResultSummary (failCount skipCount passCount totalCount)
                    testResults = junit testResults: 'junit.xml', keepLongStdio: false
                    if (_testsFailed(testResults)) {
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
    finally {
        notifyBitbucket commitSha1: scmVars.GIT_COMMIT
        notifyHipchat(currentBuild.result, scmVars, testResults)
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
        /usr/local/cpanel/3rdparty/bin/perl Makefile.PL installdirs=vendor
    '''
}
