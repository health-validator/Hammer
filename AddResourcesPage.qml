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

Page {
    id: addResourcesPage
    height: window.height - buttonsRow.height

    Connections {
        target: appmodel

        function onValidationStarted() {
            addResourcesPage.state = "VALIDATION_RESULTS"
        }
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