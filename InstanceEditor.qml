import QtQuick 2.12
import QtQuick.Controls 2.5

// Component to edit/fixup FHIR instances as easily as possible
ScrollView {
    property string myText
    property int letterHeight: textArea.font.pixelSize

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
        onTextChanged: { appmodel.resourceText = text; }
        font.family: "Ubuntu Mono"
        font.preferShaping: false
        selectByMouse: true
        wrapMode: "WrapAtWordBoundaryOrAnywhere"
        height: parent.height
    }
}
