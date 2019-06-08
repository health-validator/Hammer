import QtQuick 2.12
import QtQuick.Controls 2.5

/** A 'dashboard' display box for reporting an overview of the failure or succes of a validation step. */ 
Item {
    property string label          /** Label to show underneath the box */
    property bool   runningStatus  /** Set this to indicate if the validation is running */
    property int    errorCount     /** Set this to the number of errors during validation */
    property int    warningCount   /** Set this to the number of warnings during valudation */

    /** Activated whenever the box is clicked. */ 
    signal clicked()

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
            onClicked: parent.parent.clicked()
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
            visible: !appmodel.validatingJava
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
