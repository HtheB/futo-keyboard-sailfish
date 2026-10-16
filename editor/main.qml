import QtQuick 2.6
import Sailfish.Silica 1.0

ApplicationWindow {
    allowedOrientations: Orientation.LandscapeMask
    // Platform file-picker subpages inherit this orientation.
    _defaultPageOrientations: Orientation.LandscapeMask
    initialPage: Component { FutoEditorHome {} }
    cover: Component { FutoEditorCover {} }
}
