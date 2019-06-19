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
    ScrollBar.vertical.policy: ScrollBar.AlwaysOn
    onImplicitHeightChanged: textArea.update()

    // doesn't seem to find contentY at creation time
    //    Behavior on contentItem.contentY {
    //        PropertyAnimation {
    //            duration: 500
    //            easing.type: Easing.InOutQuad
    //        }
    //    }

    TextArea {
        id: textArea
        text: myText
        onTextChanged: { appmodel.resourceText = text }
        font.family: "Ubuntu Mono"
        font.preferShaping: false
        selectByMouse: true
        wrapMode: "WrapAtWordBoundaryOrAnywhere"
        renderType: Text.NativeRendering

        background: Rectangle {
            anchors.fill: parent
            color: "#F7F9FA"
            radius: 3
            border.width: 1
            border.color: "#E3E7FD"
        }

        // credit: https://stackoverflow.com/a/49875950/72944
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            hoverEnabled: true
            propagateComposedEvents: true
            cursorShape: containsMouse ? Qt.IBeamCursor : Qt.ArrowCursor
            onClicked: openContextMenu(mouse)
            onPressAndHold: if (mouse.source === Qt.MouseEventNotSynthesized) {
                                openContextMenu(mouse)
                            }

            function openContextMenu(mouse) {
                // keep selection when context menu is opened
                selectStart = textArea.selectionStart
                selectEnd = textArea.selectionEnd
                curPos = textArea.cursorPosition
                contextMenu.x = mouse.x
                contextMenu.y = mouse.y
                contextMenu.open()
                textArea.cursorPosition = curPos
                textArea.select(selectStart, selectEnd)
            }

            Menu {
                id: contextMenu
                MenuItem {
                    text: qsTr("Cut")
                    onTriggered: {
                        textArea.cut()
                    }
                }
                MenuItem {
                    text: qsTr("Copy")
                    onTriggered: {
                        textArea.copy()
                    }
                }
                MenuItem {
                    text: qsTr("Paste")
                    onTriggered: {
                        textArea.paste()
                    }
                }
            }
        }
    }
}
