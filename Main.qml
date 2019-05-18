import QtQuick 2.7
import QtQuick.Controls 2.5
// import test 1.1
import QtQuick.Controls.Material 2.0
import QtQuick.Window 2.10
import QtQuick.Controls.Universal 2.12
import QtQuick.Layouts 1.12
import QtQuick.Dialogs 1.3

ApplicationWindow {
    id: window
    visible: true
    width: 640; height: 480
    minimumWidth: 550; minimumHeight: 300
    title: qsTr("Hammer")

    Universal.theme: Universal.Light

    NetObject {
        id: dotnet
    }

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
                           dotnet.loadDragAndDrop(drop.text)
                           drop.acceptProposedAction()
                           addResourceScrollView.state = "ENTERING_RESOURCE"
                       }
                   }
    }

    Page {
        id: addResourcesPage
        width: window.width
        height: window.height - buttonsRow.height


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
                    folder: dotnet.scopeDirectory ? "file://" + dotnet.scopeDirectory : shortcuts.home
                    onAccepted: dotnet.loadDragAndDrop(resourcePicker.fileUrl)
                }
            }

            TextArea {
                id: textArea
                placeholderText: qsTr("or load it here")
                renderType: Text.NativeRendering
                onTextChanged: dotnet.updateText(text)
//                onEditingFinished: dotnet.updateText(text)
                text: dotnet.resourceText
                font.family: dotnet.resourceText ? "Ubuntu Mono" : "Ubuntu"
                selectByMouse: true
                wrapMode: "WrapAtWordBoundaryOrAnywhere"

                // unused, was a workaround for focus loss on delete
                function syncText() {
                    // going from no text to some text causes a loss of focus - restore it
                    // seems to be a ParentChange issue (or I'm doing it wrong)
                    textArea.forceActiveFocus()
                    reportDimensions()
                }

                function reportDimensions() {
                    console.log(`textarea: x: ${textArea.x} y: ${textArea.y} w: ${textArea.width} h: ${textArea.height}, s: ${textArea.state}`)
                    console.log(`scroll visible? ${addResourceScrollView.visible} x: ${addResourceScrollView.x} y: ${addResourceScrollView.y} w: ${addResourceScrollView.width} h: ${addResourceScrollView.height}, children: ${addResourceScrollView.children.length}`)
                }

                Shortcut {
                    sequence: "Ctrl+R"
                    onActivated: {
                        console.log("validating via shortcut");
                        addResourcesPage.state = "VALIDATED_RESOURCE"
                        dotnet.startValidation()
                    }
                }

                states: [
                    State {
                        name: "MINIMAL"; when: !dotnet.resourceText
                        ParentChange {
                            target: textArea
                            parent: loadResourcesRow
                            width: 300
                            height: loadResourceButton.height
                        }
                    },
                    State {
                        name: "EXPANDED"; when: dotnet.resourceText
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
                        NumberAnimation { properties: "x,y,width,height";  easing.type: Easing.InCubic; duration: 600 }
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
                PropertyChanges { target: actionButton; text: dotnet.validateButtonText}
            },
            State {
                name: "VALIDATED_RESOURCE"
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
                from: "*"; to: "VALIDATED_RESOURCE"
                NumberAnimation { property: "x"; easing.type: Easing.InBack; duration: 1000 }
            },
            Transition {
                from: "*"; to: "ENTERING_RESOURCE"
                NumberAnimation { property: "x"; easing.type: Easing.InBack; duration: 1000 }
                NumberAnimation { property: "y"; easing.type: Easing.OutBack; duration: 1000 }
            },
            Transition {
                from: "*"; to: "EDITING_SETTINGS"
                NumberAnimation { property: "y"; easing.type: Easing.OutBack; duration: 1000 }
            }
        ]
    }

    RowLayout {
        id: buttonsRow
        x: 0
        y: parent.height - height
        width: window.width
        visible: dotnet.resourceText

        Button {
            id: actionButton
            text: dotnet.validateButtonText
            Layout.fillWidth: true

            onClicked: {
                if (addResourcesPage.state === "ENTERING_RESOURCE") {
                    addResourcesPage.state = "VALIDATED_RESOURCE"
                    dotnet.startValidation()
                } else {
                    addResourcesPage.state = "ENTERING_RESOURCE"
                }
            }

            ToolTip.visible: hovered && dotnet.scopeDirectory
            ToolTip.text: qsTr(`Scope: <code>${dotnet.scopeDirectory}</code>`)
        }

        Button {
            id: settingsButton
            text: "☰"

            onClicked: addResourcesPage.state = "EDITING_SETTINGS"
        }
    }

    Pane {
        id: resultsPane
        width: window.width
        height: parent.height - actionButton.height
        x: resultsPane.width

        Rectangle {
            id: noErrorsRectangle
            width: 300
            height: 130
            radius: 20
            color: "#5d8130"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            visible: !dotnet.validating && dotnet.errorCount === 0

            Label {
                width: 294
                height: 45
                text: "<center>✓ Valid</center>"
                color: "white"
                font.pointSize: 26
                textFormat: Text.RichText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        ColumnLayout {
            id: errorsColumn
            spacing: 20
            anchors.fill: parent
            visible: !dotnet.validating && dotnet.errorCount >= 1

            Rectangle {
                id: errorsRectangle
                width: 250; height: 90; radius: 5
                color: "#d04746"; border.color: "#c33f3f"
                border.width: 2
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                Label {
                    width: 294
                    height: 45
                    color: "white"
                    text: "<center>invalid</center>"
                    font.pointSize: 26
                    textFormat: Text.RichText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ScrollView {
                clip: true
                Layout.fillHeight: true
                Layout.fillWidth: true

                Column {
                    anchors.left: parent.left
                    spacing: 5

                    Repeater {
                        id: errorsRepeater

                        Rectangle {
                            id: messageRectangle
                            color: "#f8fafb"
                            border.color: "#f6f3fb"
                            border.width: 1

                            height: errorText.height + 20
                            width: resultsPane.width - leftMargin - rightMargin

                            property int leftMargin: 20
                            property int rightMargin: 15

                            visible: {
                                if (modelData.severity === "error" && showErrors.checked) {
                                    return true
                                } else if (modelData.severity === "warning" && showWarnings.checked) {
                                    return true
                                }  else if (modelData.severity === "informational" && showInfo.checked) {
                                    return true
                                } else {
                                    return false
                                }
                            }

                            Rectangle {
                                width: 10
                                height: errorText.height + 20
                                anchors.left: parent.left
                                color: modelData.severity === "error" ? "#cc5555" : modelData.severity === "warning" ? "#f0ad4e" : "#007ec6"
                            }

                            Text {
                                id: errorText
                                anchors {
                                    left: parent.left; leftMargin: messageRectangle.leftMargin
                                    right: parent.right; rightMargin: messageRectangle.rightMargin
                                    top: parent.top; topMargin: 10
                                }

                                width: parent.width
                                color: "#337081"
                                text: modelData.text
                                renderType: Text.NativeRendering
                                textFormat: Text.PlainText
                                wrapMode: "WrapAtWordBoundaryOrAnywhere"
                            }
                        }
                    }
                }
            }
        }

        BusyIndicator {
            running: dotnet.validating
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            onRunningChanged: errorsRepeater.model = Net.toListModel(dotnet.issues)
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
                text: dotnet.scopeDirectory
                onCursorPositionChanged: dotnet.loadScopeDirectory(text)
                onEditingFinished: dotnet.loadScopeDirectory(text)
                selectByMouse: true
                placeholderText: qsTr("Current scope: none")
                Layout.columnSpan: 2
                Layout.fillWidth: true
            }
            Button {
                text: "<center>Browse...</center>"
                onClicked: scopePicker.open()

                FileDialog {
                    id: scopePicker
                    title: "Folder to act as the scope (context) for validation"
                    folder: dotnet.scopeDirectory ? "file://" + dotnet.scopeDirectory : shortcuts.home
                    selectFolder: true
                    onAccepted: dotnet.loadScopeDirectory(scopePicker.fileUrl)
                }
            }

            Text {
                text: qsTr("Messages to show")
                font.pointSize: settingsPane.headerFontSize
                font.bold: true
                Layout.fillWidth: true
                Layout.columnSpan: 3
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
    D{i:32;anchors_height:130;anchors_width:300}D{i:31;anchors_height:130;anchors_width:300}
D{i:36;anchors_height:130;anchors_width:300}D{i:35;anchors_height:130;anchors_width:300}
D{i:37;anchors_height:130;anchors_width:300}D{i:34;anchors_height:130;anchors_width:300}
}
 ##^##*/
