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
    property int animationDuration: appmodel.animateQml ? 700 : 0

    StateGroup {
        id: hammerState

        states: [
            State {
                name: "SINGLE_RESOURCE"
                PropertyChanges { target: singleResourcePage; visible: true }
                PropertyChanges { target: multipleResourcesView; visible: false }
                PropertyChanges { target: tabsview; visible: false }
                PropertyChanges { target: settingsPane; y: window.height }
                PropertyChanges { target: actionButton; text: appmodel.validateButtonText }
            },
            State {
                name: "MULTIPLE_RESOURCES"
                PropertyChanges { target: singleResourcePage; visible: false }
                PropertyChanges { target: multipleResourcesView; visible: true }
                PropertyChanges { target: tabsview; visible: true }
                PropertyChanges { target: settingsPane; y: window.height }
                PropertyChanges { target: actionButton; text: appmodel.validateButtonText }
            },
            State {
                name: "EDITING_SETTINGS"
                PropertyChanges { target: settingsPane; y: 0 }
                PropertyChanges { target: actionButton; text: qsTr("⮪ Back")}
            }
        ]
        transitions: [
            Transition {
                from: "*"; to: "SINGLE_RESOURCE"
                NumberAnimation { property: "x"; easing.type: Easing.InBack; duration: animationDuration }
                NumberAnimation { property: "y"; easing.type: Easing.InBack; duration: animationDuration }
            },
            Transition {
                from: "*"; to: "EDITING_SETTINGS"
                NumberAnimation { property: "y"; easing.type: Easing.OutBack; duration: animationDuration }
            }
        ]
        state: "SINGLE_RESOURCE"
    }

    Connections {
        target: appmodel
        function onResourcesLoaded (count) {
            hammerState.state = (count < 2) ? "SINGLE_RESOURCE" : "MULTIPLE_RESOURCES"
        }
    }

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
                           resourcePage.state = "ENTERING_RESOURCE"
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
        onActivated: { resourcePage.state = "ENTERING_RESOURCE"; resourcePicker.open() }
    }

    ButtonGroup {
        buttons: tabsview.children
    }

    ListView {
        id: tabsview
        anchors.top: parent.top
        anchors.left: parent.left
        implicitWidth: contentItem.childrenRect.width
        height: parent.height - buttonsRow.height

        Component.onCompleted: tabsview.currentIndex = 0

        Connections {
            target: appmodel
            function onResourcesLoaded (count) {
                if (count < 2) {
                    return
                }

                tabsview.model = Net.toListModel(appmodel.loadedResources)
                tabsview.currentIndex = 0
            }
        }

        // has to be manually updated since we're loading data through Net.toListModel
        // onCurrentIndexChanged: multipleResourcesView.positionViewAtIndex(currentIndex, ListView.Beginning)
        onCurrentIndexChanged: multipleResourcesView.currentIndex = currentIndex

        delegate: TabButton {
            id: control
            text: modelData.name
            width: 250
            onClicked: tabsview.currentIndex = index
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

    ResourcePage {
        id: singleResourcePage
        state: "ENTERING_RESOURCE"
        width: window.width
        resourcePicker: resourcePicker

        Connections {
            target: appmodel
            function onResourcesLoaded (count) {
                if (count >= 2) {
                    return
                }

                let model = Net.toListModel(appmodel.loadedResources)
                singleResourcePage.name = model.at(0).name
                singleResourcePage.resourceText = model.at(0).text
                singleResourcePage.originalFilename = model.at(0).originalFilename
            }
        }
    }

    ListView {
        id: multipleResourcesView
        currentIndex: tabsview.currentIndex
        width: parent.width
        height: parent.height - buttonsRow.height
        anchors.top: parent.top
        anchors.left: tabsview.right
        keyNavigationEnabled: true
        interactive: true
        snapMode: ListView.SnapOneItem

        Component.onCompleted: multipleResourcesView.currentIndex = 0

        onCurrentIndexChanged: {
            tabsview.currentIndex = currentIndex
            console.log(`multipleResourcesView current index ${currentIndex} `)
        }

	    delegate: ResourcePage {
	        id: resourcePage
	        state: "ENTERING_RESOURCE"
	        width: window.width
            name: modelData.name
            resourceText: modelData.text
            originalFilename: modelData.originalFilename
            resourcePicker: resourcePicker
	    }

        Connections {
            target: appmodel
            function onResourcesLoaded (count) {
                if (count < 2) {
                    return
                }

                multipleResourcesView.model = Net.toListModel(appmodel.loadedResources)
                multipleResourcesView.currentIndex = 0
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

            onClicked: hammerState.state = "EDITING_SETTINGS"
            ToolTip.visible: hovered; ToolTip.delay: tooltipDelay
            ToolTip.text: qsTr(`Open settings`)
        }

        Button {
            id: loadNewInstanceButton
            text: "📂"
            // visible: textArea.state === "EXPANDED"

            onClicked: resourcePicker.open()

            ToolTip.visible: hovered; ToolTip.delay: tooltipDelay
            ToolTip.text: qsTr(`Open new instance (Ctrl+O)`)
        }

        Button {
            id: actionButton
            // this should be set declaratively
            text: appmodel.validateButtonText
            visible: appmodel.resourceText || hammerState.state === "EDITING_SETTINGS"
            Layout.fillWidth: true

            onClicked: {
                if (hammerState.state === "EDITING_SETTINGS") {
                    hammerState.state = "SINGLE_RESOURCE"
                    return
                }

                if (hammerState.state === "SINGLE_RESOURCE" &&
                    (singleResourcePage.state === "ENTERING_RESOURCE"
                        || (singleResourcePage.state === "VALIDATION_RESULTS"
                          //  && resultsPageEditor.state === "VISIBLE"
                        ))) {
                    appmodel.startValidation(0)
                } else {
                    if (resourcePage.state === "VALIDATION_RESULTS") {
                        appmodel.cancelValidation()
                    }
                    resourcePage.state = "ENTERING_RESOURCE"
                }
            }

            ToolTip.visible: hovered && appmodel.scopeDirectory
            ToolTip.text: qsTr(`Scope: ${appmodel.scopeDirectory}\nTerminology: ${appmodel.terminologyService}`)
        }
    }

    SettingsPane {
        id: settingsPane
        height: multipleResourcesView.height
        horizontalPadding: 40
        width: multipleResourcesView.width
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
