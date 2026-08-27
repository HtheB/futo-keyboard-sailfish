import QtQuick 2.0
import Sailfish.Silica 1.0
import org.nemomobile.devicelock 1.0
import com.jolla.settings.system 1.0

// Stock-style device-lock input page whose AuthenticationInput is supplied by
// FutoDeviceAuthentication.  Keeping the input on a real page makes PIN entry
// responsive while the explicit method mask also permits fingerprint unlock.
Page {
    id: page

    property AuthenticationInput authentication

    backNavigation: false
    opacity: status === PageStatus.Active ? 1.0 : 0.0

    DeviceLockInput {
        authenticationInput: page.authentication
        showEmergencyButton: false
    }
}
