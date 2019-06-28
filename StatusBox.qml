import QtQuick 2.12
import QtQuick.Controls 2.5

/** A 'dashboard' display box for reporting an overview of the failure or succes of a validation step. */
Item {
    property string label          /** Label to show underneath the box */
    property bool   runningStatus  /** Set this to indicate if the validation is running */
    property var    dataModel
    
    property int    errorCount
    property int    warningCount
    property int    infoCount

    onDataModelChanged: {
        var error = 0
        var warning = 0
        var info = 0

        for (var i = 0; i < dataModel.rowCount(); i++) {
            var severity = dataModel.data(dataModel.index(i, 0)).severity
            if (severity == "information") info++
            else if (severity == "warning") warning++
            else if (severity == "error" | severity == "fatal") error++
        }

        errorCount = error
        warningCount = warning
        infoCount = info
    }

    /** Activated whenever the box is clicked. */
    signal clicked()
    signal rightClicked()

    height: 100

    Rectangle {
        id: mainErrorsRectangle
        border.color: "grey"
        radius: 3
        anchors.fill: parent
        anchors.margins: 20

        MouseArea {
            hoverEnabled: true
            anchors.fill: parent
            cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: if (mouse.button === Qt.RightButton) {
                           parent.parent.rightClicked()
                       } else {
                           parent.parent.clicked()
                       }
        }

        BusyIndicator {
            running: runningStatus
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            radius: 3
            anchors.margins: 1
            anchors.fill: parent
            visible: !runningStatus && errorCount === 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00b09b" }
                GradientStop { position: 1.0; color: "#96c93d" }
                orientation: Gradient.Vertical
            }
        }
        Rectangle {
            radius: 3
            anchors.margins: 1
            anchors.fill: parent
            visible: !runningStatus && errorCount > 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#c31432" }
                GradientStop { position: 1.0; color: "#240b36" }
                orientation: Gradient.Vertical
            }
        }

        Label {
            text: qsTr(`${errorCount} ∙ ${warningCount}`)
            font.pointSize: 35
            anchors.centerIn: parent
            visible: !runningStatus
            color: "white"


            ToolTip.visible: errorsMouseArea.containsMouse
            ToolTip.text: qsTr(`${errorCount} Errors ∙ ${warningCount} Warnings`)

            MouseArea {
                id: errorsMouseArea;
                hoverEnabled: true;
                anchors.fill: parent;
            }
        }
    }

    Label {
        text: label
        anchors.horizontalCenter: mainErrorsRectangle.horizontalCenter
        anchors.top: mainErrorsRectangle.bottom
        anchors.topMargin: 6
        color: "#696969"
        font.pointSize: 11
    }
}
