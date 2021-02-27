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

    ResultsPane {
        id: resultsPane
        width: window.width
        x: resultsPane.width
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
