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

    FileDialog {
        id: resourcePicker
        title: "Select FHIR resource(s) to validate"
        folder: appmodel.scopeDirectory ? "file://" + appmodel.scopeDirectory : StandardPaths.standardLocations(StandardPaths.DesktopLocation)[0]
        onAccepted: appmodel.loadResourceFile(convertUriToString(resourcePicker.files))
        fileMode: FileDialog.OpenFiles

        function convertUriToString(files) {
            var stringFiles = [];
            for (var i  = 0; i < files.length; i++) {
                stringFiles.push(files[i].toString());
            }

            return stringFiles;
        }
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: { addResourcesPage.state = "ENTERING_RESOURCE"; resourcePicker.open() }
    }

    ButtonGroup {
        buttons: bar.children
    }

    ListView {
        id: bar
        anchors.top: parent.top
        anchors.left: parent.left
        implicitWidth: contentItem.childrenRect.width
        height: parent.height - buttonsRow.height

        Component.onCompleted: bar.currentIndex = 0

        Connections {
            target: appmodel
            onResourcesLoaded: {
                bar.model = Net.toListModel(appmodel.loadedResources)
                bar.currentIndex = 0
            }
        }

        // has to be manually updated since we're loading data through Net.toListModel
        onCurrentIndexChanged: addResourcesParent.positionViewAtIndex(currentIndex, ListView.Beginning)

        delegate: TabButton {
            text: modelData.name
            onClicked: bar.currentIndex = index
        }

        populate: Transition {
            id: trans
            SequentialAnimation {
                NumberAnimation {
                    properties: "opacity";
                    from: 1
                    to: 0
                    duration: 0
                }
                PauseAnimation {
                    duration: (trans.ViewTransition.index -
                                trans.ViewTransition.targetIndexes[0]) * 20
                }
                ParallelAnimation {
                    NumberAnimation {
                        properties: "opacity";
                        from: 0
                        to: 1
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        properties: "y";
                        from: trans.ViewTransition.destination.y + 50
                        duration: 620
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    ListView {
        id: addResourcesParent
        currentIndex: bar.currentIndex
        width: parent.width
        height: parent.height - buttonsRow.height
        anchors.top: parent.top
        anchors.left: bar.right
        keyNavigationEnabled: true
        interactive: true
        snapMode: ListView.SnapOneItem

        Component.onCompleted: addResourcesParent.currentIndex = 0

        onCurrentIndexChanged: {
            bar.currentIndex = currentIndex
            console.log(`addResourcesParent current index ${currentIndex} `)
        }

	    delegate: AddResourcesPage {
	        id: addResourcesPage
	        state: "ENTERING_RESOURCE"
	        width: window.width
            name: modelData.name
            resourceText: modelData.text
            originalFilename: modelData.originalFilename
	    }

        Connections {
            target: appmodel
            onResourcesLoaded: {
                addResourcesParent.model = Net.toListModel(appmodel.loadedResources)
                addResourcesParent.currentIndex = 0
            }
        }

        // displaced: Transition {
        //     NumberAnimation { properties: "x,y"; duration: 1000 }
        // }
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
        height: addResourcesParent.height
        horizontalPadding: 40
        width: addResourcesParent.width
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
