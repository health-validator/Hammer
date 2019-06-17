import QtQuick 2.12
import QtQuick.Controls 2.5

// Component to edit/fixup FHIR instances as easily as possible
Item {
    property string text           /** Instance text content */

    TextArea {
        id: textArea
        renderType: Text.NativeRendering
        text: appmode.resourceText
        font.family: "Ubuntu Mono"
        selectByMouse: true
        wrapMode: "WrapAtWordBoundaryOrAnywhere"
    }
}
