# Qt Compose input-context notice

The bundled `libcomposeplatforminputcontextplugin.so` is built from the Qt
5.6.3 Compose platform input-context sources in `qtbase`, copyright The Qt
Company Ltd. and contributors.

Those sources are available under the GNU Lesser General Public License,
version 2.1 or version 3, with The Qt Company LGPL Exception version 1.1. The
corresponding license texts and source are available from the Qt 5.6.3 source
archive at <https://download.qt.io/archive/qt/5.6/5.6.3/submodules/>. This
package dynamically links the plugin to the unmodified Qt libraries supplied
by Sailfish OS.

The build uses the original Qt 5.6.3 Compose implementation. Its purpose here
is to provide the component expected by Sailfish's Maliit input context so
physical-keyboard dead-key sequences can be completed.
