import QtQuick 2.12
import QtQuick.Controls 2.12
// import appmodel 1.0
import QtQuick.Controls.Material 2.12
import QtQuick.Window 2.12
import QtQuick.Controls.Universal 2.12
import QtQuick.Layouts 1.12
import QtQml 2.12
import Qt.labs.platform 1.1
import Qt.labs.settings 1.0

Pane {
    id: resultsPane
    height: parent.height - actionButton.height
    // Context menu with the options to copy the validation report as
    // Markdown or CSV, and optionally to copy a single message. To enable
    // this option, call the openWithMessageOption(message) function.
    Menu {
        id: contextMenu

        function openWithMessageOption(message) {
            singleMessageItem.message = message
            singleMessageItem.visible = true
            open()
        }
        onAboutToHide: singleMessageItem.visible = false

        MenuItem {
            id: singleMessageItem
            property string message: ""
            visible: false // Normally hidden, unless explicitly shown using openWithMessageOption()

            text: qsTr("Copy message")
            onTriggered: {
                if (message != "") {
                    appmodel.copyToClipboard(message)
                    toast.show(qsTr("Copied message to clipboard"))
                }
            }
        }
        MenuItem {
            text: qsTr("Copy report as CSV")
            onTriggered: {
                appmodel.copyValidationReportCsv()
                toast.show(qsTr("Copied all results as a CSV"))
            }
        }
        MenuItem {
            text: qsTr("Copy report as Markdown")
            onTriggered: {
                appmodel.copyValidationReportMarkdown();
                toast.show(qsTr("Copied as Markdown (works well in Zulip)"))
            }
        }
    }

    ColumnLayout {
        id: errorsColumn
        anchors.fill: parent

        Row {
            id: errorCountsRow
            //                Layout.fillWidth: true
            width: resultsPane.availableWidth
            bottomPadding: 30

            StatusBox {
                id: dotnetErrorsBox
                label: ".NET"
                width: resultsPane.availableWidth/2

                runningStatus: appmodel.validatingDotnet
                dataModel: if (!appmodel.validatingDotnet) Net.toListModel(appmodel.dotnetIssues)
                showWarnings: settings.showWarnings
                showInfo: settings.showInfo

                onClicked: errorsScrollView.contentItem.contentY = dotnetErrorList.y
                onRightClicked: if (!appmodel.validatingDotnet) contextMenu.open()
            }

            StatusBox {
                id: javaErrorsBox
                label: "Java (beta)"
                width: resultsPane.availableWidth/2

                runningStatus: appmodel.validatingJava
                dataModel: if (!appmodel.validatingJava) Net.toListModel(appmodel.javaIssues)
                showWarnings: settings.showWarnings
                showInfo: settings.showInfo

                onClicked: errorsScrollView.contentItem.contentY = javaErrorList.y
                onRightClicked: if (!appmodel.validatingJava) contextMenu.open()
            }
        }

        ScrollView {
            id: errorsScrollView
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true

            contentWidth: parent.width
            contentHeight: errorsRepeaterColumn.height

            Column {
                id: errorsRepeaterColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 5

                add: Transition {
                    NumberAnimation { properties: "x,y"; easing.type: Easing.OutBounce; duration: animationDuration }
                }

                function peekIssue(lineNumber, linePosition) {
                    if (lineNumber === 0 && linePosition === 0) { return; }
                    resultsPageEditor.state = "VISIBLE"
                    resultsPageEditor.openError(lineNumber, linePosition)
                }

                IssuesList {
                    id: dotnetErrorList
                    label: ".NET"
                    dataModel: if (!appmodel.validatingDotnet) Net.toListModel(appmodel.dotnetIssues)
                    onPeekIssue: parent.peekIssue(lineNumber, linePosition)
                    onRightClickedOnMessage: contextMenu.openWithMessageOption(message)
                    showWarnings: settings.showWarnings
                    showInfo: settings.showInfo
                }

                IssuesList {
                    id: javaErrorList
                    label: !appmodel.javaValidationCrashed ? "Java" : "Java (validation crashed, details below)"
                    dataModel: if (!appmodel.validatingJava) Net.toListModel(appmodel.javaIssues)
                    onPeekIssue: parent.peekIssue(lineNumber, linePosition)
                    onRightClickedOnMessage: contextMenu.openWithMessageOption(message)
                    showWarnings: settings.showWarnings
                    showInfo: settings.showInfo
                }
            }
        }

        InstanceEditor {
            id: resultsPageEditor
            instanceText: appmodel.resourceText
            fontName: monospaceFont.name
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom

            states: [
                State {
                    name: "HIDDEN"
                    PropertyChanges { target: resultsPageEditor; implicitHeight: 0 }
                },
                State {
                    name: "VISIBLE"
                    PropertyChanges { target: resultsPageEditor; implicitHeight: 250 }
                    PropertyChanges { target: actionButton; text: qsTr("Re-validate")}
                }
            ]
            state: "HIDDEN"

            transitions: [
                Transition {
                    from: "*"; to: "VISIBLE"
                    NumberAnimation { properties: "implicitHeight"; easing.type: Easing.InBack; duration: animationDuration/2 }
                },
                Transition {
                    from: "*"; to: "HIDDEN"
                    NumberAnimation { properties: "implicitHeight"; easing.type: Easing.InBack; duration: animationDuration/2 }
                }
            ]
        }
    }
}
