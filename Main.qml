import QtQuick 2.12
import QtQuick.Controls 2.12
// import appmodel 1.0
import QtQuick.Controls.Material 2.12
import QtQuick.Window 2.12
import QtQuick.Controls.Universal 2.12
import QtQuick.Layouts 1.12
import QtQuick.Dialogs 1.3

ApplicationWindow {
    id: window
    visible: true
    width: 640; height: 650
    minimumWidth: 550; minimumHeight: 300
    title: qsTr("Hammer STU3 (experimental)")

    Universal.theme: darkAppearanceSwitch.checked ? Universal.Dark : Universal.Light

    AppModel {
        id: appmodel
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
                           appmodel.loadResourceFile(drop.text)
                           drop.acceptProposedAction()
                           addResourceScrollView.state = "ENTERING_RESOURCE"
                       }
                   }
    }

    Shortcut {
        sequence: "Ctrl+D"
        onActivated: if (appmodel.resourceText) {
            addResourcesPage.state = "VALIDATED_RESOURCE"
            appmodel.startValidation()
        }
    }


    Shortcut {
        sequence: "Ctrl+O"
        onActivated: resourcePicker.open()
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: {
            appmodel.loadResourceFile("file:///home/vadi/Desktop/swedishnationalmedicationlist/MedicationRequest-example-bad.json")
            addResourcesPage.state = "VALIDATED_RESOURCE"
            appmodel.startValidation()
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
                    folder: appmodel.scopeDirectory ? "file://" + appmodel.scopeDirectory : shortcuts.home
                    onAccepted: appmodel.loadResourceFile(resourcePicker.fileUrl)
                }

                ToolTip.text: qsTr("Ctrl+O (open), Ctrl+D (validate)")
                ToolTip.visible: hovered; ToolTip.delay: 1000
            }

            TextArea {
                id: textArea
                placeholderText: qsTr("or load it here")
                renderType: Text.NativeRendering
                onTextChanged: appmodel.updateText(text)
                text: appmodel.resourceText
                // ensure the tooltip isn't monospace, only the text
                font.family: appmodel.resourceText ? "Ubuntu Mono" : "Ubuntu"
                selectByMouse: true
                wrapMode: "WrapAtWordBoundaryOrAnywhere"

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
                PropertyChanges { target: actionButton; text: appmodel.validateButtonText}
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

        Button {
            id: settingsButton
            text: "☰"

            onClicked: addResourcesPage.state = "EDITING_SETTINGS"
        }

        Button {
            id: copyResultsButton
            text: "📋"
            font.family: "Apple Color Emoji"
            visible: addResourcesPage.state === "VALIDATED_RESOURCE"
            enabled: !appmodel.validatingDotnet || !appmodel.validatingJava
            onClicked: appmodel.copyValidationReport()

            ToolTip.visible: hovered
            ToolTip.text: qsTr(`Copy validation report as a CSV to clipboard`)
        }

        Button {
            id: actionButton
            text: appmodel.validateButtonText
            visible: appmodel.resourceText || addResourcesPage.state === "EDITING_SETTINGS"
            Layout.fillWidth: true

            onClicked: {
                if (addResourcesPage.state === "ENTERING_RESOURCE") {
                    addResourcesPage.state = "VALIDATED_RESOURCE"
                    appmodel.startValidation()
                } else {
                    addResourcesPage.state = "ENTERING_RESOURCE"
                }
            }

            ToolTip.visible: hovered && appmodel.scopeDirectory
            ToolTip.text: qsTr(`Scope: ${appmodel.scopeDirectory}`)
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
            anchors.centerIn: parent
//            visible: !appmodel.validating &&
//                     appmodel.dotnetResult.errorCount === 0 && appmodel.javaResult.errorCount === 0
            visible: false

            Label {
                width: 294
                height: 45
                text: "<center>✓ Valid</center>"
                color: "white"
                font.pointSize: 26
                textFormat: Text.RichText
                anchors.centerIn: parent
            }
        }

        ColumnLayout {
            id: errorsColumn
            spacing: 20
            anchors.fill: parent
//            visible: !appmodel.validating &&
//                     (appmodel.dotnetResult.errorCount >= 1 || appmodel.javaResult.errorCount >= 1)

            Rectangle {
                id: errorsRectangle
                width: 250; height: 90; radius: 5
                border.color: "#c33f3f"
                border.width: 2
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#c31432" }
                    GradientStop { position: 1.0; color: "#240b36" }
                    orientation: Gradient.Vertical
                }

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

            Row {
                id: errorCountsRow
//                Layout.fillWidth: true
                width: resultsPane.availableWidth
                bottomPadding: 10

                Item {
                    id: dotnetErrorsBox
//                    property int errors: appmodel.dotnetResult ?   appmodel.dotnetResult.errorCount   : 0
//                    property int warnings: appmodel.dotnetResult ? appmodel.dotnetResult.warningCount : 0
                    width: resultsPane.availableWidth/2
                    height: 100

                    Rectangle {
                        id: dotnetErrorsRectangle
                        border.color: "grey"
                        radius: 3
                        anchors.fill: parent
                        anchors.margins: 20

                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: errorsScrollView.contentItem.contentY = dotnetErrorsLabel.y
                        }

                        BusyIndicator {
                            running: appmodel.validatingDotnet
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onRunningChanged: dotnetErrorsRepeater.model = Net.toListModel(appmodel.dotnetResult.issues)
                        }

                        Label {
                            color: "#696969"
                            text: qsTr(`${appmodel.dotnetResult.errorCount} ∙ ${appmodel.dotnetResult.warningCount}`)
                            font.pointSize: 35
                            anchors.centerIn: parent
                            visible: !appmodel.validatingDotnet

                            ToolTip.visible: dotnetErrorsMouseArea.containsMouse
                            ToolTip.text: qsTr("Errors ∙ Warnings")

                            MouseArea {
                                id: dotnetErrorsMouseArea; hoverEnabled: true; anchors.fill: parent
                            }
                        }
                    }
                    Label {
                        text: ".NET"
                        anchors.horizontalCenter: dotnetErrorsRectangle.horizontalCenter
                        anchors.top: dotnetErrorsRectangle.bottom
                        anchors.topMargin: 6
                        color: "#696969"
                        font.pointSize: 11
                    }
                }

                Item {
                    id: javaErrorsBox
                    // property int errors: appmodel.javaResult? appmodel.javaResult.errorCount : 0
                    // property int warnings: appmodel.javaResult? appmodel.javaResult.warningCount : 0
                    width: resultsPane.availableWidth/2
                    height: 100

                    Rectangle {
                        id: javaErrorsRectangle
                        border.color: "grey"
                        radius: 3
                        anchors.fill: parent
                        anchors.margins: 20

                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: errorsScrollView.contentItem.contentY = javaErrorsLabel.y
                        }

                        BusyIndicator {
                            running: appmodel.validatingJava
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            onRunningChanged: javaErrorsRepeater.model = Net.toListModel(appmodel.javaResult.issues)
                        }

                        Label {
                            color: "#696969"
                            text: qsTr(`${appmodel.javaResult.errorCount} ∙ ${appmodel.javaResult.warningCount}`)
                            font.pointSize: 35
                            anchors.centerIn: parent
                            visible: !appmodel.validatingJava

                            ToolTip.visible: javaErrorsMouseArea.containsMouse
                            ToolTip.text: qsTr("Errors ∙ Warnings")

                            MouseArea {
                                id: javaErrorsMouseArea; hoverEnabled: true; anchors.fill: parent
                            }
                        }
                    }
                    Label {
                        text: "Java (beta)"
                        anchors.horizontalCenter: javaErrorsRectangle.horizontalCenter
                        anchors.top: javaErrorsRectangle.bottom
                        anchors.topMargin: 6
                        color: "#696969"
                        font.pointSize: 11
                    }
                }

            }

            ScrollView {
                id: errorsScrollView
                Layout.fillHeight: true
                Layout.fillWidth: true
                clip: true
                contentHeight: errorsRepeaterColumn.height

                Column {
                    id: errorsRepeaterColumn
                    anchors.left: parent.left
                    spacing: 5

                    add: Transition {
                        NumberAnimation { properties: "x,y"; easing.type: Easing.OutBounce; duration: 1000 }
                    }

                    Label {
                        id: dotnetErrorsLabel
                        text: ".NET"
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#696969"
                        font.pointSize: 17
                        visible: !appmodel.validatingDotnet
                    }

                    Repeater {
                        id: dotnetErrorsRepeater

                        Rectangle {
                            id: messageRectangle
                            color: "#f8fafb"
                            border.color: "#f6f3fb"
                            border.width: 1

                            height: errorText.height + 30
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
                                border.color: "#c33f3f"
                                border.width: 1

                                gradient: Gradient {
                                    GradientStop { position: 0.0
                                        color: modelData.severity === "error" ? "#c31432" :
                                               modelData.severity === "warning" ? "#fe8c00" : "#007ec6"
                                    }
                                    GradientStop { position: 1.0
                                        color: modelData.severity === "error" ? "#240b36" :
                                               modelData.severity === "warning" ? "#f83600" : "#007ec6"
                                    }
                                }
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

                            Text {
                                id: errorLocationText
                                anchors {
                                    bottom: parent.bottom
                                }

                                width: parent.width
                                horizontalAlignment: Text.AlignRight
                                color: "#34826b"
                                text: modelData.location
                                renderType: Text.NativeRendering
                                font.pointSize: 9
                                textFormat: Text.PlainText
                                wrapMode: "WrapAtWordBoundaryOrAnywhere"
                            }
                        }
                    }

                    Label {
                        id: javaErrorsLabel
                        text: !appmodel.javaValidationCrashed ? "Java" : "Java (validation crashed, details below)"
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#696969"
                        font.pointSize: 17
                        visible: !appmodel.validatingJava
                    }

                    Repeater {
                        id: javaErrorsRepeater

                        Rectangle {
                            id: javaMessageRectangle
                            color: "#f8fafb"
                            border.color: "#f6f3fb"
                            border.width: 1

                            height: javaErrorText.height + 30
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
                                height: javaErrorText.height + 20
                                anchors.left: parent.left

                                gradient: Gradient {
                                    GradientStop { position: 0.0
                                        color: modelData.severity === "error" ? "#c31432" :
                                               modelData.severity === "warning" ? "#fe8c00" : "#007ec6"
                                    }
                                    GradientStop { position: 1.0
                                        color: modelData.severity === "error" ? "#240b36" :
                                               modelData.severity === "warning" ? "#f83600" : "#007ec6"
                                    }
                                }
                            }

                            Text {
                                id: javaErrorText
                                anchors {
                                    left: parent.left; leftMargin: javaMessageRectangle.leftMargin
                                    right: parent.right; rightMargin: javaMessageRectangle.rightMargin
                                    top: parent.top; topMargin: 10
                                }

                                width: parent.width
                                color: "#337081"
                                text: modelData.text
                                renderType: Text.NativeRendering
                                textFormat: Text.PlainText
                                wrapMode: "WrapAtWordBoundaryOrAnywhere"
                            }

                            Text {
                                id: errorJavaLocationText
                                anchors {
                                    bottom: parent.bottom
                                }

                                width: parent.width
                                horizontalAlignment: Text.AlignRight
                                color: "#34826b"
                                text: modelData.location
                                renderType: Text.NativeRendering
                                font.pointSize: 9
                                textFormat: Text.PlainText
                                wrapMode: "WrapAtWordBoundaryOrAnywhere"
                            }
                        }
                    }

                }
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

                FileDialog {
                    id: scopePicker
                    title: "Folder to act as the scope (context) for validation"
                    folder: appmodel.scopeDirectory ? "file://" + appmodel.scopeDirectory : shortcuts.home
                    selectFolder: true
                    onAccepted: appmodel.loadScopeDirectory(scopePicker.fileUrl)
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
