import QtQuick 2.12
import QtQuick.Controls 2.5

// Component to edit/fixup FHIR instances as easily as possible
ScrollView {
    property string myText

    clip: true

    onMyTextChanged: console.log(`my text changed`)

    TextArea {
        id: textArea
        renderType: Text.NativeRendering
        text: myText
        font.family: "Ubuntu Mono"
        font.preferShaping: false
        selectByMouse: true
        wrapMode: "WrapAtWordBoundaryOrAnywhere"
    }
}
