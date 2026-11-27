/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "launcherbadges.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusServiceWatcher>
#include <QDebug>

namespace
{
const QString unityService = QStringLiteral("com.canonical.Unity");

// Claims com.canonical.Unity once per process, never releasing it
void claimUnityName(QDBusConnection bus)
{
    static bool attempted = false;
    if (attempted) {
        return;
    }
    attempted = true;
    if (!bus.registerService(unityService)) {
        qWarning() << "LauncherBadges: could not claim" << unityService << "- owned by"
                   << bus.interface()->serviceOwner(unityService).value();
    }
}
}

LauncherBadges::LauncherBadges(QObject *parent)
    : QObject(parent)
    , m_watcher(new QDBusServiceWatcher(this))
{
    QDBusConnection bus = QDBusConnection::sessionBus();

    m_watcher->setConnection(bus);
    m_watcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &sender) {
        m_watcher->removeWatchedService(sender);
        m_state.senderGone(sender);
    });
    connect(&m_state, &BadgeState::changed, this, &LauncherBadges::countsChanged);

    bus.connect(QString(),
                QString(),
                QStringLiteral("com.canonical.Unity.LauncherEntry"),
                QStringLiteral("Update"),
                this,
                SLOT(onUpdate(QString, QVariantMap, QDBusMessage)));
    claimUnityName(bus);
}

QVariantMap LauncherBadges::counts() const
{
    return m_state.counts();
}

void LauncherBadges::onUpdate(const QString &appUri, const QVariantMap &properties, const QDBusMessage &message)
{
    const QString sender = message.service();
    m_state.update(sender, appUri, properties);
    watch(sender);
}

void LauncherBadges::watch(const QString &sender)
{
    if (m_watcher->watchedServices().contains(sender)) {
        return;
    }
    m_watcher->addWatchedService(sender);
    const QDBusReply<bool> registered = QDBusConnection::sessionBus().interface()->isServiceRegistered(sender);
    if (registered.isValid() && !registered.value()) {
        m_watcher->removeWatchedService(sender);
        m_state.senderGone(sender);
    }
}
