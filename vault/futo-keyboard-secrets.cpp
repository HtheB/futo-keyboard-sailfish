/*
 * Narrow Sailfish Secrets bridge for FUTO Keyboard.
 *
 * It never accepts secret bytes in argv and never prints metadata alongside a
 * successful key.  The Go helper reads the 32 raw bytes through a private pipe.
 */
#include <QtCore/QCoreApplication>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QString>

#include <Secrets/result.h>
#include <Secrets/secret.h>
#include <Secrets/secretmanager.h>
#include <Secrets/lockcoderequest.h>
#include <Secrets/storedsecretrequest.h>
#include <Secrets/storesecretrequest.h>

#include <cstdio>
#include <limits.h>
#include <unistd.h>

using namespace Sailfish::Secrets;

namespace {

const int KeySize = 32;

bool hasTrustedHelperParent()
{
    // This bridge writes raw encryption key bytes to an inherited anonymous
    // pipe.  It must never be useful when another same-user application starts
    // it directly, especially because the accompanying polkit rule suppresses
    // Sailfish Secrets' redundant second prompt for this exact process chain.
    char target[PATH_MAX + 1];
    const QByteArray parentExe = QByteArrayLiteral("/proc/")
            + QByteArray::number(getppid()) + QByteArrayLiteral("/exe");
    const ssize_t length = readlink(parentExe.constData(), target, PATH_MAX);
    if (length <= 0 || length > PATH_MAX)
        return false;
    target[length] = '\0';
    return QByteArray(target, int(length))
            == QByteArrayLiteral("/usr/libexec/futo-keyboard-helper");
}

QString secretName(const QString &kind)
{
    return kind == QStringLiteral("vault")
            ? QStringLiteral("org.hb.FutoKeyboard.vault-key-v1")
            : QStringLiteral("org.hb.FutoKeyboard.learned-key-v1");
}

bool writeRawKey(const QByteArray &key)
{
    if (key.size() != KeySize)
        return false;
    QFile output;
    if (!output.open(stdout, QIODevice::WriteOnly))
        return false;
    return output.write(key) == key.size() && output.flush();
}

QByteArray randomKey()
{
    QFile random(QStringLiteral("/dev/urandom"));
    if (!random.open(QIODevice::ReadOnly))
        return QByteArray();
    return random.read(KeySize);
}

Result readKey(SecretManager *manager, const QString &name,
               SecretManager::UserInteractionMode interaction,
               QByteArray *key)
{
    StoredSecretRequest request;
    request.setManager(manager);
    request.setIdentifier(Secret::Identifier(
            name, QString(), SecretManager::DefaultStoragePluginName));
    request.setUserInteractionMode(interaction);
    request.startRequest();
    request.waitForFinished();
    if (request.result().code() == Result::Succeeded)
        *key = request.secret().data();
    return request.result();
}

Result storeKey(SecretManager *manager, const QString &name,
                const QString &kind, const QByteArray &key)
{
    Secret secret(name, QString(), SecretManager::DefaultStoragePluginName);
    secret.setType(Secret::TypeBlob);
    secret.setData(key);

    StoreSecretRequest request;
    request.setManager(manager);
    request.setSecretStorageType(StoreSecretRequest::StandaloneDeviceLockSecret);
    // Standalone device-lock secrets use the regular storage plugin plus the
    // separate encryption plugin.  Sailfish Secrets deliberately rejects an
    // encrypted-storage plugin here because it cannot re-encrypt standalone
    // secrets when the device-lock key changes.
    request.setEncryptionPluginName(SecretManager::DefaultEncryptionPluginName);
    request.setAuthenticationPluginName(SecretManager::DefaultAuthenticationPluginName);
    request.setSecret(secret);
    request.setDeviceLockUnlockSemantic(kind == QStringLiteral("vault")
            ? SecretManager::DeviceLockVerifyLock
            : SecretManager::DeviceLockKeepUnlocked);
    request.setAccessControlMode(SecretManager::OwnerOnlyMode);
    request.setUserInteractionMode(SecretManager::SystemInteraction);
    request.startRequest();
    request.waitForFinished();
    return request.result();
}

Result unlockMasterDatabase(SecretManager *manager)
{
    // Retrieving a secret cannot unlock Sailfish Secrets' bookkeeping
    // database.  This dedicated request is executed only by the separately
    // installed, setgid-privileged master-unlock bridge.  It returns no key
    // material; the regular unprivileged bridge performs the subsequent read.
    LockCodeRequest request;
    request.setManager(manager);
    request.setLockCodeRequestType(LockCodeRequest::ProvideLockCode);
    request.setLockCodeTargetType(LockCodeRequest::MetadataDatabase);
    request.setLockCodeTarget(QString());
    request.setUserInteractionMode(SecretManager::SystemInteraction);
    request.startRequest();
    request.waitForFinished();
    return request.result();
}

bool requiresUnlockInteraction(Result::ErrorCode error)
{
    // Depending on how long the phone has been locked, Sailfish may report
    // the lock at the daemon, plugin, or collection layer.  All three mean
    // the existing secret is present and must be opened interactively; none
    // of them may be treated as a missing key.
    return error == Result::SecretsDaemonLockedError
            || error == Result::SecretsPluginIsLockedError
            || error == Result::CollectionIsLockedError;
}

int fail(const Result &result, const char *operation)
{
    std::fprintf(stderr, "futo-keyboard-secrets: %s failed (%d)\n",
                 operation, int(result.errorCode()));
    return 2;
}

} // namespace

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    const QStringList arguments = application.arguments();

    // The set-group-ID master unlocker is deliberately a separate installed
    // entry point. A credential-changing process cannot reliably inspect its
    // unprivileged parent's /proc/<pid>/exe on Sailfish, so identify this
    // narrow, no-output operation by its canonical executable path instead.
    // It never reads or returns a FUTO key; all key operations below continue
    // to require the trusted helper parent check.
    const QString executablePath = QFileInfo(application.applicationFilePath())
            .canonicalFilePath();
    if (executablePath
            == QStringLiteral("/usr/libexec/futo-keyboard-master-unlock")) {
        if (arguments.size() != 2
                || arguments.at(1) != QStringLiteral("unlock-master")) {
            std::fprintf(stderr,
                         "futo-keyboard-secrets: unsupported master-unlock operation\n");
            return 64;
        }
        SecretManager manager;
        const Result result = unlockMasterDatabase(&manager);
        return result.code() == Result::Succeeded
                ? 0 : fail(result, "master unlock");
    }

    if (!hasTrustedHelperParent()) {
        std::fprintf(stderr, "futo-keyboard-secrets: untrusted parent process\n");
        return 77;
    }
    if (arguments.size() != 3
            || (arguments.at(1) != QStringLiteral("get")
                && arguments.at(1) != QStringLiteral("ensure")
                && arguments.at(1) != QStringLiteral("unlock")
                && arguments.at(1) != QStringLiteral("prepare"))
            || (arguments.at(2) != QStringLiteral("learned")
                && arguments.at(2) != QStringLiteral("vault"))) {
		std::fprintf(stderr, "Usage: futo-keyboard-secrets get|ensure|unlock|prepare learned|vault\n");
        return 64;
    }

    const QString operation = arguments.at(1);
    const QString kind = arguments.at(2);
    const QString name = secretName(kind);
    SecretManager manager;

    QByteArray key;
    Result result = readKey(&manager, name,
            kind == QStringLiteral("vault")
                ? SecretManager::SystemInteraction
                : SecretManager::PreventInteraction,
            &key);
    if (result.code() == Result::Succeeded)
        return writeRawKey(key) ? 0 : 3;

    // A Settings DeviceLockQuery normally leaves the device-lock collection
    // available, so first try the non-interactive read above.  If the Secrets
    // daemon still reports an explicitly locked collection, unlock may request
    // the system interaction.  It must never create or replace a key.
    if (operation == QStringLiteral("unlock")
            || operation == QStringLiteral("prepare")) {
        if (kind == QStringLiteral("learned")
                && requiresUnlockInteraction(result.errorCode())) {
            result = readKey(&manager, name, SecretManager::SystemInteraction, &key);
            if (result.code() == Result::Succeeded)
                return writeRawKey(key) ? 0 : 3;
        }
        if (operation == QStringLiteral("unlock")
                || result.errorCode() != Result::InvalidSecretError)
            return fail(result, "unlock");
    }
    if (operation == QStringLiteral("get"))
        return fail(result, "read");

    // Only a genuinely absent secret may be initialized.  In particular,
    // CollectionIsLockedError must not be treated as absence.
    if (result.errorCode() != Result::InvalidSecretError)
        return fail(result, "read before ensure");

    key = randomKey();
    if (key.size() != KeySize) {
        std::fprintf(stderr, "futo-keyboard-secrets: random key generation failed\n");
        return 3;
    }
    result = storeKey(&manager, name, kind, key);
    if (result.code() != Result::Succeeded)
        return fail(result, "store");
    return writeRawKey(key) ? 0 : 3;
}
