import QtQuick 2.12
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.12

/** List the error and warning messages of the validation step. */
ColumnLayout {
    id: rootComponent
    property string label        /** The label for the current collection of messages */
    property bool   labelVisible /** Set this to indicate if the label should be visible */ 
    property var    dataModel    /** Set this to the datamodel from the C# side */

    anchors.left: parent.left
    anchors.right: parent.right

    signal peekIssue(string text)

    Label {
        text: label
        Layout.alignment: Qt.AlignCenter
        color: "#696969"
        font.pointSize: 17
        visible: labelVisible
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

            height: errorText.height + 30
            width: parent.width - leftMargin - rightMargin
            implicitHeight: errorText.height + 30
            implicitWidth: parent.width - leftMargin - rightMargin

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

            // Color indicator for the type of message
            Rectangle {
                width: 10
                height: errorText.height + 30
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

            // The error message location
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

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: rootComponent.peekIssue(modelData.text)
            }
        }
    }
}
