import QtQuick 2.12
import QtQuick.Controls 2.5

// Component to edit/fixup FHIR instances as easily as possible
ScrollView {
    property string instanceText
    property string fontName

    /** Scroll the text to the specified line number
      * @param lineNumber the line number, with counting started at 1
      */
    function openError(lineNumber, linePosition) {
        // We can't calculate the y position directly because a logical and
        // displayed line might differ in height due to line wrapping. QML's
        // positionToRectangle() function can tell us what we need, but for
        // that we have to calculate the position in the text string of the
        // line.
        var position = 0
        const lines = textArea.text.split("\n")
        for (var currentLine = 0; currentLine < lineNumber - 1; currentLine++) {
            position += lines[currentLine].length + 1 // include newline char
        }
        contentItem.contentY = textArea.positionToRectangle(position).y
        textArea.forceActiveFocus()
        textArea.cursorPosition = position + linePosition - 1 // don't include last newline char
    }

    clip: true
    ScrollBar.vertical.policy: ScrollBar.AlwaysOn
    onImplicitHeightChanged: textArea.update()

    TextArea {
        id: textArea
        text: instanceText

        onTextChanged: appmodel.resourceText = text
        font.family: fontName
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
                const selectStart = textArea.selectionStart
                const selectEnd = textArea.selectionEnd
                const curPos = textArea.cursorPosition
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
