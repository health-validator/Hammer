import QtQuick 2.12

// To use the QML Settings object, it is needed to set the application name
// and domain from the programming side with the QGuiApplication methods 
// .setApplicationName() and setOrganizationDomain(). This is not supported
// in Qml.Net however, but it can be set from the QML side as well.
// Unfortunately, the earliest that this can be triggered is in a
// Component.onCompleted callback. This is too late, as the Settings object
// is of course instantiated before completion.
// To 'solve' this, this QML file can be loaded separately and *before* the
// main QML file with the Settings object. This will cause the name and domain
// to be set before the main file starts loading. 
Item {
    Component.onCompleted: {
        Qt.application.name = "Hammer"
        Qt.application.domain = "hammer.mc"
    }
}