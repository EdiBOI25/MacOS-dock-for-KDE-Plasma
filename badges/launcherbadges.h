/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QDBusMessage>
#include <QObject>
#include <QVariantMap>
#include <qqmlregistration.h>

#include "badgestate.h"

class QDBusServiceWatcher;

// Unity launcher badge counts from the session bus, for QML
class LauncherBadges : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantMap counts READ counts NOTIFY countsChanged)

public:
    explicit LauncherBadges(QObject *parent = nullptr);

    QVariantMap counts() const;

Q_SIGNALS:
    void countsChanged();

private Q_SLOTS:
    void onUpdate(const QString &appUri, const QVariantMap &properties, const QDBusMessage &message);

private:
    void watch(const QString &sender);

    BadgeState m_state;
    QDBusServiceWatcher *m_watcher;
};
