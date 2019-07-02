import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.12

/** List the error and warning messages of the validation step. */
ColumnLayout {
    id: rootComponent
    property string label        /** The label for the current collection of messages */
    property var    dataModel    /** Set this to the datamodel from the C# side */
    property bool   showErrors   /** Show messages with severity 'error' or 'fatal' */
    property bool   showWarnings /** Show messages with severity 'warning' */
    property bool   showInfo     /** Show messages with severity 'informational' */

    anchors.left: parent.left
    anchors.right: parent.right

    signal peekIssue(int lineNumber, int linePosition)
    signal rightClicked()

    Label {
        text: label
        Layout.alignment: Qt.AlignCenter
        color: "#696969"
        font.pointSize: 17
        visible: messagesRepeater.count > 0
    }

    Repeater {
        id: messagesRepeater
        model: dataModel

        // Main container for the message
        Rectangle {
            id: messageRectangle
            color: "#f8fafb"
            border.color: "#f6f3fb"
            border.width: 1

            height: errorText.height + 40
            width: parent.width - leftMargin - rightMargin
            implicitHeight: errorText.height + 40
            implicitWidth: parent.width - leftMargin - rightMargin

            property int leftMargin: 20
            property int rightMargin: 15

            visible: {
                if (modelData.severity === "error" && showErrors) {
                    return true
                } else if (modelData.severity === "warning" && showWarnings) {
                    return true
                }  else if (modelData.severity === "information" && showInfo) {
                    return true
                } else {
                    return false
                }
            }

            // Color indicator for the type of message
            Rectangle {
                width: 10
                height: errorText.height + 40
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

            // The error message text
            Text {
                id: errorText
                anchors {
                    left: parent.left; leftMargin: messageRectangle.leftMargin
                    right: parent.right; rightMargin: messageRectangle.rightMargin
                    top: parent.top; topMargin: 10
                }

                color: "#337081"
                text: modelData.text
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                wrapMode: "WrapAtWordBoundaryOrAnywhere"
            }

            // The error message location (as fhirpath)
            Text {
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

            // The error message location (as line:column)
            Text {
                anchors {
                    bottom: parent.bottom
                    left: parent.left; leftMargin: messageRectangle.leftMargin
                }

                width: parent.width
                horizontalAlignment: Text.AlignLeft
                color: "#34826b"
                visible: modelData.lineNumber !== 0
                text: `line ${modelData.lineNumber}:${modelData.linePosition}`
                renderType: Text.NativeRendering
                font.pointSize: 9
                textFormat: Text.PlainText
                wrapMode: "WrapAtWordBoundaryOrAnywhere"

                opacity: mousearea.containsMouse ? 1.0 : 0
                Behavior on opacity {
                    OpacityAnimator {
                        duration: 250
                    }
                }
            }

            MouseArea {
                id: mousearea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: if (mouse.button === Qt.RightButton) {
                               rootComponent.rightClicked()
                           } else {
                               rootComponent.peekIssue(modelData.lineNumber, modelData.linePosition)
                           }
            }
        }
    }
}
