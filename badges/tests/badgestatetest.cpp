/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "badgestate.h"

#include <QSignalSpy>
#include <QTest>

namespace
{
QVariantMap props(std::initializer_list<std::pair<QString, QVariant>> values)
{
    QVariantMap map;
    for (const auto &[key, value] : values) {
        map.insert(key, value);
    }
    return map;
}
}

class BadgeStateTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void discordUpdateShowsCount()
    {
        BadgeState state;
        QSignalSpy changed(&state, &BadgeState::changed);

        state.update(QStringLiteral(":1.229"),
                     QStringLiteral("application://discord"),
                     props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(1)},
                            {QStringLiteral("count-visible"), true}}));

        QCOMPARE(state.counts(), (QVariantMap{{QStringLiteral("discord"), 1}}));
        QCOMPARE(changed.count(), 1);
    }

    void desktopSuffixIsStripped()
    {
        BadgeState state;
        state.update(QStringLiteral(":1.5"),
                     QStringLiteral("application://org.mozilla.Thunderbird.desktop"),
                     props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(7)},
                            {QStringLiteral("count-visible"), true}}));

        QCOMPARE(state.counts(), (QVariantMap{{QStringLiteral("org.mozilla.Thunderbird"), 7}}));
    }

    void badUrisAreIgnored()
    {
        BadgeState state;
        QSignalSpy changed(&state, &BadgeState::changed);
        const QVariantMap visibleCount = props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(2)},
                                                {QStringLiteral("count-visible"), true}});

        state.update(QStringLiteral(":1.5"), QStringLiteral("file:///usr/share/applications/x.desktop"), visibleCount);
        state.update(QStringLiteral(":1.5"), QStringLiteral("application://"), visibleCount);
        state.update(QStringLiteral(":1.5"), QStringLiteral("application://.desktop"), visibleCount);
        state.update(QStringLiteral(":1.5"), QString(), visibleCount);

        QVERIFY(state.counts().isEmpty());
        QCOMPARE(changed.count(), 0);
    }

    void partialUpdatesAreMerged()
    {
        BadgeState state;
        const QString sender = QStringLiteral(":1.5");
        const QString uri = QStringLiteral("application://discord");

        state.update(sender, uri, props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(3)},
                                         {QStringLiteral("count-visible"), true}}));
        state.update(sender, uri, props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(4)}}));
        QCOMPARE(state.counts(), (QVariantMap{{QStringLiteral("discord"), 4}}));

        state.update(sender, uri, props({{QStringLiteral("count-visible"), false}}));
        QVERIFY(state.counts().isEmpty());

        state.update(sender, uri, props({{QStringLiteral("count-visible"), true}}));
        QCOMPARE(state.counts(), (QVariantMap{{QStringLiteral("discord"), 4}}));
    }

    void countWithoutVisibleFlagIsHidden()
    {
        BadgeState state;
        state.update(QStringLiteral(":1.5"), QStringLiteral("application://discord"),
                     props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(5)}}));

        QVERIFY(state.counts().isEmpty());
    }

    void senderGoneClearsOnlyItsApps()
    {
        BadgeState state;
        const QVariantMap visibleCount = props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(2)},
                                                {QStringLiteral("count-visible"), true}});
        state.update(QStringLiteral(":1.5"), QStringLiteral("application://discord"), visibleCount);
        state.update(QStringLiteral(":1.9"), QStringLiteral("application://signal"), visibleCount);
        QSignalSpy changed(&state, &BadgeState::changed);

        state.senderGone(QStringLiteral(":1.5"));

        QCOMPARE(state.counts(), (QVariantMap{{QStringLiteral("signal"), 2}}));
        QCOMPARE(changed.count(), 1);
    }

    void staleSenderGoneKeepsNewerSendersBadge()
    {
        BadgeState state;
        const QString uri = QStringLiteral("application://discord");
        state.update(QStringLiteral(":1.5"), uri, props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(1)},
                                                         {QStringLiteral("count-visible"), true}}));
        state.update(QStringLiteral(":1.7"), uri, props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(3)}}));

        state.senderGone(QStringLiteral(":1.5"));

        QCOMPARE(state.counts(), (QVariantMap{{QStringLiteral("discord"), 3}}));
    }

    void zeroCountIsHidden()
    {
        BadgeState state;
        state.update(QStringLiteral(":1.5"), QStringLiteral("application://discord"),
                     props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(0)},
                            {QStringLiteral("count-visible"), true}}));

        QVERIFY(state.counts().isEmpty());

        state.update(QStringLiteral(":1.5"), QStringLiteral("application://discord"),
                     props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(3)}}));
        QCOMPARE(state.counts(), (QVariantMap{{QStringLiteral("discord"), 3}}));

        state.update(QStringLiteral(":1.5"), QStringLiteral("application://discord"),
                     props({{QStringLiteral("count"), QVariant::fromValue<qlonglong>(0)}}));
        QVERIFY(state.counts().isEmpty());
    }
};

QTEST_GUILESS_MAIN(BadgeStateTest)
#include "badgestatetest.moc"
