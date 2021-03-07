import QtQuick 2.12
import QtQuick.Controls 2.12
import appmodel 1.0
import QtQuick.Controls.Universal 2.12
import QtQuick.Layouts 1.12
import Qt.labs.platform 1.1
import Qt.labs.settings 1.0

Pane {
    id: settingsPane

    property alias appearDark:   darkAppearanceSwitch.checked
    property alias showWarnings: showWarningsBox.checked
    property alias showInfo:     showInfoBox.checked

    readonly property int headerFontSize: 14

    GridLayout {
        id: grid
        columns: 3
        anchors.fill: parent
        rowSpacing: 10

        Text {
            text: qsTr("Validating with FHIR")
            color: Universal.foreground
            font.pointSize: settingsPane.headerFontSize
            font.bold: true
            Layout.fillWidth: true; Layout.columnSpan: 3
            topPadding: 10
        }
        ComboBox {
            id: fhirVersionCombobox
            model: ["STU3", "R4"]
            onActivated: {
                appmodel.fhirVersion = currentText
                // FIXME: window binding for the fhirVersion didn't seem to work, requires an imperactive approach here
                window.title = qsTr(`Hammer experimental ${appmodel.fhirVersion} ${appmodel.applicationVersion}`)
            }
        }

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
            text: qsTr("Show errors and...")
            color: Universal.foreground
            font.pointSize: settingsPane.headerFontSize
            font.bold: true
            Layout.fillWidth: true; Layout.columnSpan: 3
            topPadding: 10
        }
        RowLayout {
            Layout.columnSpan: 2
            CheckBox {
                id: showWarningsBox
                text: qsTr("Warnings")
                checked: true
            }
            CheckBox {
                id: showInfoBox
                text: qsTr("Info")
                checked: true
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
