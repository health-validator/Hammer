import QtQuick 2.12
import QtQuick.Controls 2.12
import appmodel 1.0
import QtQuick.Controls.Material 2.12
import QtQuick.Window 2.12
import QtQuick.Controls.Universal 2.12
import QtQuick.Layouts 1.12
import Qt.labs.platform 1.1

ApplicationWindow {
    id: window
    visible: true
    width: 640; height: 650
    minimumWidth: 550; minimumHeight: 300
    title: qsTr("Hammer STU3 (experimental)")

    Universal.theme: darkAppearanceSwitch.checked ? Universal.Dark : Universal.Light

    property int tooltipDelay: 1500
    property int animationDuration: appmodel.animateQml ? 1000 : 0

    AppModel {
        id: appmodel
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

    Page {
        id: addResourcesPage
        width: window.width
        height: window.height - buttonsRow.height

        Connections {
            target: appmodel
            onValidationStarted: addResourcesPage.state = "VALIDATION_RESULTS"
        }

        ScrollView {
            id: addResourceScrollView
            anchors.fill: parent
            visible: textArea.state === "EXPANDED"
            clip: true
        }

        Label {
            id: hammerLabel
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            text: qsTr("🔨 Hammer")
            font.bold: true
            opacity: 0.6
            font.pointSize: 36
            font.family: "Apple Color Emoji"
            visible: textArea.state === "MINIMAL"
        }

        Row {
            id: loadResourcesRow
            y: hammerLabel.y + 80
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Button {
                id: loadResourceButton
                text: qsTr("Choose an instance")
                visible: textArea.state === "MINIMAL"
                onClicked: resourcePicker.open()

                FileDialog {
                    id: resourcePicker
                    title: "Select a FHIR resource to validate"
                    folder: appmodel.scopeDirectory ? "file://" + appmodel.scopeDirectory : StandardPaths.standardLocations(StandardPaths.DesktopLocation)[0]
                    onAccepted: appmodel.loadResourceFile(resourcePicker.file)
                }

                ToolTip.text: qsTr("Ctrl+O (open), Ctrl+D (validate)")
                ToolTip.visible: hovered; ToolTip.delay: tooltipDelay
            }

            InstanceEditor {
                id: textArea
                instancePlaceholder: qsTr("or load it here")
                instanceText: appmodel.resourceText
                // ensure the tooltip isn't monospace, only the text
                fontName: appmodel.resourceText ? monospaceFont.name : "Ubuntu"

                anchors.top: loadResourceButton.top
                anchors.bottom: loadResourceButton.bottom

                onParentChanged: textArea.forceActiveFocus()

                states: [
                    State {
                        name: "MINIMAL"; when: !appmodel.resourceText
                        ParentChange {
                            target: textArea
                            parent: loadResourcesRow
                            width: 300
                            height: undefined
                        }
                    },
                    State {
                        name: "EXPANDED"; when: appmodel.resourceText
                        ParentChange {
                            target: textArea
                            parent: addResourceScrollView
                            x: 0; y: 0
                            width: addResourcesPage.width
                            height: addResourcesPage.height
                        }
                    }
                ]
                state: "MINIMAL"

                transitions: Transition {
                    ParentAnimation {
                        NumberAnimation { properties: "x,y,width,height"; easing.type: Easing.InCubic; duration: 600 }
                    }
                }
            }

        }

        Text {
            id: experimentalText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Experimental")
            enabled: false
            z: 0
            rotation: -45
            opacity: 0.1
            font.pixelSize: 96
        }

        states: [
            State {
                name: "ENTERING_RESOURCE"
                PropertyChanges { target: addResourcesPage; x: 0 }
                PropertyChanges { target: resultsPane; x: resultsPane.width }
                PropertyChanges { target: settingsPane; y: window.height }
                PropertyChanges { target: actionButton; text: appmodel.validateButtonText }
            },
            State {
                name: "VALIDATION_RESULTS"
                PropertyChanges { target: addResourcesPage; x: addResourcesPage.width * -1 }
                PropertyChanges { target: resultsPane; x: 0 }
                PropertyChanges { target: settingsPane; y: window.height }
                PropertyChanges { target: actionButton; text: qsTr("⮪ Back")}
            },
            State {
                name: "EDITING_SETTINGS"
                PropertyChanges { target: settingsPane; y: 0 }
                PropertyChanges { target: actionButton; text: qsTr("⮪ Back")}
            }
        ]
        state: "ENTERING_RESOURCE"

        transitions: [
            Transition {
                from: "*"; to: "VALIDATION_RESULTS"
                NumberAnimation { property: "x"; easing.type: Easing.InBack; duration: animationDuration }
            },
            Transition {
                from: "*"; to: "ENTERING_RESOURCE"
                NumberAnimation { property: "x"; easing.type: Easing.InBack; duration: animationDuration }
                NumberAnimation { property: "y"; easing.type: Easing.OutBack; duration: animationDuration }
            },
            Transition {
                from: "*"; to: "EDITING_SETTINGS"
                NumberAnimation { property: "y"; easing.type: Easing.OutBack; duration: animationDuration }
            }
        ]
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

        Menu {
            id: contextMenu
            MenuItem {
                text: qsTr("Copy all as CSV")
                onTriggered: { appmodel.copyValidationReport(); toast.show(qsTr("Copied all results as a CSV")) }
            }
        }

        function openContextMenu() {
            contextMenu.open()
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
                    errorCount:    appmodel.dotnetErrorCount
                    warningCount:  appmodel.dotnetWarningCount

                    onClicked: errorsScrollView.contentItem.contentY = dotnetErrorList.y
                    onRightClicked: if (!appmodel.validatingDotnet) resultsPane.openContextMenu()
                }

                StatusBox {
                    id: javaErrorsBox
                    label: "Java (beta)"
                    width: resultsPane.availableWidth/2

                    runningStatus: appmodel.validatingJava
                    errorCount:    appmodel.javaErrorCount
                    warningCount:  appmodel.javaWarningCount

                    onClicked: errorsScrollView.contentItem.contentY = javaErrorList.y
                    onRightClicked: if (!appmodel.validatingJava) resultsPane.openContextMenu()
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
                        labelVisible: !appmodel.validatingDotnet && (appmodel.dotnetErrorCount >= 1 || appmodel.dotnetWarningCount >= 1)
                        dataModel: if (!appmodel.validatingDotnet) Net.toListModel(appmodel.dotnetIssues)
                        onPeekIssue: parent.peekIssue(lineNumber, linePosition)
                        onRightClicked: resultsPane.openContextMenu()
                    }

                    IssuesList {
                        id: javaErrorList
                        label: !appmodel.javaValidationCrashed ? "Java" : "Java (validation crashed, details below)"
                        labelVisible: !appmodel.validatingJava && (appmodel.javaErrorCount >= 1 || appmodel.javaWarningCount >= 1)
                        dataModel: if (!appmodel.validatingJava) Net.toListModel(appmodel.javaIssues)
                        onPeekIssue: parent.peekIssue(lineNumber, linePosition)
                        onRightClicked: resultsPane.openContextMenu()
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

    Pane {
        id: settingsPane
        height: addResourcesPage.height; width: addResourcesPage.width
        x: 0; y: window.height
        horizontalPadding: 40

        property int headerFontSize: 14

        GridLayout {
            id: grid
            columns: 3
            anchors.fill: parent
            rowSpacing: 10

            Text {
                text: qsTr("Scope")
                color: Universal.foreground
                font.pointSize: settingsPane.headerFontSize
                font.bold: true

                Layout.columnSpan: 3

                ToolTip.visible: scopeMouseArea.containsMouse
                ToolTip.text: qsTr("The scope (context) that this resource should be validated in.\nCurrently only folders are considered - packages are coming soon")

                MouseArea {
                    id: scopeMouseArea; hoverEnabled: true; anchors.fill: parent
                }
            }
            TextField {
                text: appmodel.scopeDirectory
                onTextChanged: appmodel.loadScopeDirectory(text)
                selectByMouse: true
                placeholderText: qsTr("Current scope: none")
                Layout.columnSpan: 2
                Layout.fillWidth: true
            }
            Button {
                text: "<center>Browse...</center>"
                onClicked: scopePicker.open()

                FolderDialog {
                    id: scopePicker
                    title: "Folder to act as the scope (context) for validation"
                    folder: appmodel.scopeDirectory ? "file://" + appmodel.scopeDirectory : StandardPaths.standardLocations(StandardPaths.DesktopLocation)[0]
                    onAccepted: appmodel.loadScopeDirectory(scopePicker.folder)
                }
            }

            Text {
                text: qsTr("Show me")
                color: Universal.foreground
                font.pointSize: settingsPane.headerFontSize
                font.bold: true
                Layout.fillWidth: true; Layout.columnSpan: 3
                topPadding: 10
            }
            RowLayout {
                Layout.columnSpan: 3
                CheckBox {
                    id: showErrors
                    text: qsTr("Errors")
                    checked: true
                    Layout.fillWidth: true
                }
                CheckBox {
                    id: showWarnings
                    text: qsTr("Warnings")
                    checked: true
                    Layout.fillWidth: true
                }
                CheckBox {
                    id: showInfo
                    text: qsTr("Info")
                    checked: true
                    Layout.fillWidth: true
                }
            }

            Text {
                text: qsTr("Appearance")
                color: Universal.foreground
                font.pointSize: settingsPane.headerFontSize
                font.bold: true
                Layout.fillWidth: true
                Layout.columnSpan: 3
                topPadding: 10
            }

            Switch {
                id: darkAppearanceSwitch
                text: qsTr("Dark")
            }

            Item {
                id: spanner
                Layout.columnSpan: 3
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
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
