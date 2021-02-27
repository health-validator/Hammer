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

ApplicationWindow {
    id: window
    Component.onCompleted: settings.isWindowMaximized ? showMaximized() : showNormal()
    width: 640; height: 650
    minimumWidth: 550; minimumHeight: 300
    title: qsTr(`Hammer STU3 ${appmodel.applicationVersion}`)

    Universal.theme: settings.appearDark ? Universal.Dark : Universal.Light

    property int tooltipDelay: 1500
    property int animationDuration: appmodel.animateQml ? 1000 : 0

    AppModel {
        id: appmodel

        onUpdateAvailable: function(newversion) {
            toast.show(qsTr(`New Hammer ${newversion} available! <a href="https://github.com/health-validator/Hammer/releases">Download update</a>`), 20000)
        }

    }

    ToastManager {
        id: toast
    }

    FontLoader { id: monospaceFont; source: "RobotoMono-Regular.ttf" }

    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: {
            console.log(`raw text: ${drag.text}`)
            let location = drag.text.replace(/\r?\n/, "")
            if (!location.endsWith(".json") && !location.endsWith(".xml")) {
                drag.accepted = false
            }
        }

        onDropped: if (drop.hasText && drop.text) {
                       if (drop.proposedAction == Qt.MoveAction || drop.proposedAction == Qt.CopyAction) {
                           appmodel.loadResourceFile(drop.text)
                           drop.acceptProposedAction()
                           addResourcesPage.state = "ENTERING_RESOURCE"
                       }
                   }
    }

    Shortcut {
        sequence: "Ctrl+D"
        onActivated: if (appmodel.resourceText) {
            appmodel.startValidation()
        }
    }


    Shortcut {
        sequence: "Ctrl+O"
        onActivated: { addResourcesPage.state = "ENTERING_RESOURCE"; resourcePicker.open() }
    }

    AddResourcesPage {
        id: addResourcesPage
        state: "ENTERING_RESOURCE"
        width: window.width
    }

    RowLayout {
        id: buttonsRow
        x: 0
        y: parent.height - height
        width: window.width

        Button {
            id: settingsButton
            text: "☰"

            onClicked: addResourcesPage.state = "EDITING_SETTINGS"
            ToolTip.visible: hovered; ToolTip.delay: tooltipDelay
            ToolTip.text: qsTr(`Open settings`)
        }

        Button {
            id: loadNewInstanceButton
            text: "📂"
            visible: textArea.state === "EXPANDED"

            onClicked: resourcePicker.open()

            ToolTip.visible: hovered; ToolTip.delay: tooltipDelay
            ToolTip.text: qsTr(`Open new instance (Ctrl+O)`)
        }

        Button {
            id: actionButton
            // this should be set declaratively
            text: appmodel.validateButtonText
            visible: appmodel.resourceText || addResourcesPage.state === "EDITING_SETTINGS"
            Layout.fillWidth: true

            onClicked: {
                if (addResourcesPage.state === "ENTERING_RESOURCE"
                        || (addResourcesPage.state === "VALIDATION_RESULTS"
                            && resultsPageEditor.state === "VISIBLE")) {
                    appmodel.startValidation()
                } else {
                    if (addResourcesPage.state === "VALIDATION_RESULTS") {
                        appmodel.cancelValidation()
                    }
                    addResourcesPage.state = "ENTERING_RESOURCE"
                }
            }

            ToolTip.visible: hovered && appmodel.scopeDirectory
            ToolTip.text: qsTr(`Scope: ${appmodel.scopeDirectory}\nTerminology: ${appmodel.terminologyService}`)
        }
    }

    Pane {
        id: resultsPane
        width: window.width
        height: parent.height - actionButton.height
        x: resultsPane.width

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

    SettingsPane {
        id: settingsPane
        height: addResourcesPage.height
        horizontalPadding: 40
        width: addResourcesPage.width
        x: 0
        y: window.height
    }

    Settings {
        id: settings

        property alias appearDark:   settingsPane.appearDark
        property alias showWarnings: settingsPane.showWarnings
        property alias showInfo:     settingsPane.showInfo

        property alias windowWidth:  window.width
        property alias windowHeight: window.height

        property bool isWindowMaximized: false
        function updateWindowMaximized() {
            // Check only for maximized/windowed, ignore the minimalized state or hidden state on shutdown
            if (window.visibility == Window.Maximized) {
                isWindowMaximized = true
            } else if (window.visibility == Window.Windowed) {
                isWindowMaximized = false
            }
        }
    }
    onVisibilityChanged: settings.updateWindowMaximized()
}


/*##^## Designer {
    D{i:2;invisible:true}D{i:31;anchors_height:130;anchors_width:300}D{i:32;anchors_height:130;anchors_width:300}
D{i:34;anchors_height:130;anchors_width:300}D{i:36;anchors_height:130;anchors_width:300}
D{i:37;anchors_height:130;anchors_width:300}D{i:35;anchors_height:130;anchors_width:300}
D{i:5;invisible:true}D{i:41;invisible:true}D{i:42;invisible:true}D{i:40;invisible:true}
D{i:44;invisible:true}D{i:54;invisible:true}D{i:64;invisible:true}D{i:66;invisible:true}
D{i:65;invisible:true}
}
 ##^##*/
