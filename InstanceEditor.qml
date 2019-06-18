import QtQuick 2.12
import QtQuick.Controls 2.5

// Component to edit/fixup FHIR instances as easily as possible
ScrollView {
    property string myText
    property int letterHeight: textArea.font.pixelSize

    property int selectStart
    property int selectEnd
    property int curPos


    clip: true
    contentHeight: height

    // doesn't seem to find contentY at creation time
    //    Behavior on contentItem.contentY {
    //        PropertyAnimation {
    //            duration: 500
    //            easing.type: Easing.InOutQuad
    //        }
    //    }

    TextArea {
        id: textArea
        renderType: Text.NativeRendering
        text: myText
        onTextChanged: { appmodel.resourceText = text }
        font.family: "Ubuntu Mono"
        font.preferShaping: false
        selectByMouse: true
        wrapMode: "WrapAtWordBoundaryOrAnywhere"
        height: parent.height

        // credit: https://stackoverflow.com/a/49875950/72944
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            hoverEnabled: true
            onClicked: {
                selectStart = textArea.selectionStart
                selectEnd = textArea.selectionEnd
                curPos = textArea.cursorPosition
                contextMenu.x = mouse.x
                contextMenu.y = mouse.y
                contextMenu.open()
                textArea.cursorPosition = curPos
                textArea.select(selectStart, selectEnd)
            }
            onPressAndHold: {
                if (mouse.source === Qt.MouseEventNotSynthesized) {
                    selectStart = textArea.selectionStart
                    selectEnd = textArea.selectionEnd
                    curPos = textArea.cursorPosition
                    contextMenu.x = mouse.x
                    contextMenu.y = mouse.y
                    contextMenu.open()
                    textArea.cursorPosition = curPos
                    textArea.select(selectStart, selectEnd)
                }
            }

            Menu {
                id: contextMenu
                MenuItem {
                    text: "Cut"
                    onTriggered: {
                        textArea.cut()
                    }
                }
                MenuItem {
                    text: "Copy"
                    onTriggered: {
                        textArea.copy()
                    }
                }
                MenuItem {
                    text: "Paste"
                    onTriggered: {
                        textArea.paste()
                    }
                }
            }
        }
    }
}
