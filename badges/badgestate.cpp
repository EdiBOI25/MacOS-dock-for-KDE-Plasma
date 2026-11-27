/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "badgestate.h"

namespace
{
// "application://discord.desktop" or "application://discord" → "discord"
QString appIdFromUri(const QString &uri)
{
    static const QString prefix = QStringLiteral("application://");
    if (!uri.startsWith(prefix)) {
        return {};
    }
    QString id = uri.mid(prefix.size());
    if (id.endsWith(QLatin1String(".desktop"))) {
        id.chop(8);
    }
    return id;
}
}

void BadgeState::update(const QString &sender, const QString &appUri, const QVariantMap &properties)
{
    const QString id = appIdFromUri(appUri);
    if (id.isEmpty()) {
        return;
    }
    Entry &entry = m_entries[id];
    entry.sender = sender;
    if (properties.contains(QStringLiteral("count"))) {
        entry.count = properties.value(QStringLiteral("count")).toLongLong();
    }
    if (properties.contains(QStringLiteral("count-visible"))) {
        entry.visible = properties.value(QStringLiteral("count-visible")).toBool();
    }
    Q_EMIT changed();
}

void BadgeState::senderGone(const QString &sender)
{
    const auto removed = m_entries.removeIf([&sender](const auto &it) {
        return it.value().sender == sender;
    });
    if (removed > 0) {
        Q_EMIT changed();
    }
}

QVariantMap BadgeState::counts() const
{
    QVariantMap result;
    for (auto it = m_entries.cbegin(); it != m_entries.cend(); ++it) {
        if (it->visible && it->count > 0) {
            result.insert(it.key(), int(qMin<qint64>(it->count, INT_MAX)));
        }
    }
    return result;
}
