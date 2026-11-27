/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantMap>

// Unread counts per app id, built from Unity LauncherEntry updates
class BadgeState : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    void update(const QString &sender, const QString &appUri, const QVariantMap &properties);
    void senderGone(const QString &sender);
    QVariantMap counts() const;

Q_SIGNALS:
    void changed();

private:
    // Last known badge properties of one app
    struct Entry {
        qint64 count = 0;
        bool visible = false;
        QString sender;
    };

    QHash<QString, Entry> m_entries;
};
