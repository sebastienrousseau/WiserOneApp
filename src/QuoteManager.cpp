// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "QuoteManager.h"

#include "ErrorLogger.h"

#include <QCoreApplication>
#include <QDir>
#include <QRandomGenerator>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUuid>

namespace {

/**
 * @brief Initial quotes to seed the database
 * Format: {text, author, category}
 */
// clang-format off
constexpr std::array<std::tuple<const char*, const char*, const char*>, 120> INITIAL_QUOTES{{
    // Innovation & Creativity
    {"Innovation is not about saying yes to everything, but about saying no to all but the most crucial features.", "The Wiser One", "innovation"},
    {"Simplicity is the ultimate sophistication, where complexity is peeled away to reveal the essence.", "The Wiser One", "innovation"},
    {"True genius lies not in doing the extraordinary, but in elevating the ordinary.", "The Wiser One", "innovation"},
    {"The people who are crazy enough to think they can change the world are the ones who do.", "The Wiser One", "innovation"},
    {"Focus is about saying no to a thousand good ideas to embrace the one great idea that truly matters.", "The Wiser One", "innovation"},
    {"To innovate, you must be willing to embrace the discomfort of uncertainty.", "The Wiser One", "innovation"},
    {"Creativity flourishes when structure meets spontaneity.", "The Wiser One", "innovation"},
    {"The mind that opens to a new idea never returns to its original size.", "The Wiser One", "innovation"},
    {"Every breakthrough begins with a single question that challenges the status quo.", "The Wiser One", "innovation"},
    {"Innovation is seeing what everyone sees but thinking what no one has thought.", "The Wiser One", "innovation"},

    // Growth & Transformation
    {"Growth requires the courage to leave comfort behind and embrace transformation.", "The Wiser One", "growth"},
    {"The seeds of greatness are planted in moments of quiet determination.", "The Wiser One", "growth"},
    {"Every challenge you face is an opportunity to discover capabilities you never knew you had.", "The Wiser One", "growth"},
    {"The path to mastery is paved with countless small improvements.", "The Wiser One", "growth"},
    {"Spring reminds us that every ending is merely a beginning in disguise.", "The Wiser One", "growth"},
    {"New beginnings often disguise themselves as endings.", "The Wiser One", "growth"},
    {"Transformation requires the courage to face the unknown.", "The Wiser One", "growth"},
    {"The changing seasons remind us that transformation is nature's constant.", "The Wiser One", "growth"},
    {"Growth happens at the edge of comfort, where courage meets curiosity.", "The Wiser One", "growth"},
    {"The journey of self-discovery is the most rewarding voyage of all.", "The Wiser One", "growth"},

    // Wisdom & Reflection
    {"Wisdom is knowing that every moment holds the potential for transformation.", "The Wiser One", "wisdom"},
    {"The quality of your questions determines the quality of your life.", "The Wiser One", "wisdom"},
    {"Reflection is the compass that guides us toward our true north.", "The Wiser One", "wisdom"},
    {"In stillness we find the strength that busyness often obscures.", "The Wiser One", "wisdom"},
    {"Knowledge is a treasure that multiplies when shared.", "The Wiser One", "wisdom"},
    {"The pursuit of perfection often prevents the achievement of excellence.", "The Wiser One", "wisdom"},
    {"Wisdom comes to those who are willing to sit with uncertainty.", "The Wiser One", "wisdom"},
    {"Learning never exhausts the mind; it only expands its horizons.", "The Wiser One", "wisdom"},
    {"In the quiet moments of reflection, clarity emerges.", "The Wiser One", "wisdom"},
    {"The wisest mind has something yet to learn.", "The Wiser One", "wisdom"},

    // Persistence & Determination
    {"Greatness is achieved when passion and persistence challenge the impossible.", "The Wiser One", "persistence"},
    {"The future is shaped by those who dare to believe that their vision can become a reality.", "The Wiser One", "persistence"},
    {"Patience is not passive waiting, but active persistence toward your vision.", "The Wiser One", "persistence"},
    {"True strength lies in the ability to adapt while staying true to your purpose.", "The Wiser One", "persistence"},
    {"Discipline is the bridge between goals and accomplishment.", "The Wiser One", "persistence"},
    {"Resilience is the quiet refusal to be diminished by circumstance.", "The Wiser One", "persistence"},
    {"Success is the sum of small efforts repeated day in and day out.", "The Wiser One", "persistence"},
    {"The harvest of tomorrow is seeded in the efforts of today.", "The Wiser One", "persistence"},
    {"Preparation meets opportunity at the intersection called success.", "The Wiser One", "persistence"},
    {"Character is revealed not in moments of ease but in times of challenge.", "The Wiser One", "persistence"},

    // Balance & Harmony
    {"Balance is not found, it is created through mindful choices each day.", "The Wiser One", "balance"},
    {"Renewal comes to those who have the wisdom to let go of what no longer serves them.", "The Wiser One", "balance"},
    {"In the garden of life, consistency is the water that makes dreams bloom.", "The Wiser One", "balance"},
    {"Balance is the art of knowing when to hold on and when to let go.", "The Wiser One", "balance"},
    {"The equilibrium of life is maintained through continuous adjustment.", "The Wiser One", "balance"},
    {"Peace is not the absence of challenges but the presence of calm within them.", "The Wiser One", "balance"},
    {"Rest is not laziness but the foundation of sustainable achievement.", "The Wiser One", "balance"},
    {"The art of living well is the art of choosing well.", "The Wiser One", "balance"},
    {"Harmony is achieved when we align our actions with our deepest values.", "The Wiser One", "balance"},
    {"The fullness of life is found in the richness of experiences, not possessions.", "The Wiser One", "balance"},

    // Purpose & Meaning
    {"Purpose gives meaning to effort and transforms work into contribution.", "The Wiser One", "purpose"},
    {"Clarity emerges when you align your actions with your deepest values.", "The Wiser One", "purpose"},
    {"The most profound changes often begin with the simplest shifts in perspective.", "The Wiser One", "purpose"},
    {"The bridge between where you are and where you want to be is built one step at a time.", "The Wiser One", "purpose"},
    {"True leadership begins with the courage to lead yourself.", "The Wiser One", "purpose"},
    {"Progress is not measured by speed but by the consistency of direction.", "The Wiser One", "purpose"},
    {"The depth of your impact is determined by the depth of your intention.", "The Wiser One", "purpose"},
    {"Legacy is built not in grand gestures but in daily kindnesses.", "The Wiser One", "purpose"},
    {"Every decision shapes the sculpture of your future self.", "The Wiser One", "purpose"},
    {"The universe conspires to support those who move with clear intention.", "The Wiser One", "purpose"},

    // Connection & Kindness
    {"Connection is the invisible thread that weaves meaning into existence.", "The Wiser One", "connection"},
    {"Kindness is the language that transcends all barriers.", "The Wiser One", "connection"},
    {"The warmth you share with others returns to you multiplied.", "The Wiser One", "connection"},
    {"The warmth of connection dispels the coldest of days.", "The Wiser One", "connection"},
    {"The table we share becomes the memory we treasure.", "The Wiser One", "connection"},
    {"Authenticity is the foundation upon which lasting influence is built.", "The Wiser One", "connection"},
    {"In the symphony of life, every instrument has its moment to shine.", "The Wiser One", "connection"},
    {"The gift of presence is worth more than any wrapped package.", "The Wiser One", "connection"},
    {"In the darkest hour, the light of kindness shines brightest.", "The Wiser One", "connection"},
    {"Celebration is sweeter when shared with those we cherish.", "The Wiser One", "connection"},

    // Courage & Adventure
    {"Courage is not the absence of fear but action in spite of it.", "The Wiser One", "courage"},
    {"Freedom is not the absence of responsibility but its conscious embrace.", "The Wiser One", "courage"},
    {"The fire within must be tended with both passion and patience.", "The Wiser One", "courage"},
    {"Adventure awaits those who dare to step beyond the familiar.", "The Wiser One", "courage"},
    {"The horizon is not a boundary but an invitation to explore further.", "The Wiser One", "courage"},
    {"The veil between dreams and reality is thinner than we imagine.", "The Wiser One", "courage"},
    {"Light finds its way through the smallest cracks; so does hope.", "The Wiser One", "courage"},
    {"The stars remind us that light can travel immense distances to reach us.", "The Wiser One", "courage"},
    {"Every sunrise offers a fresh canvas upon which to paint your intentions.", "The Wiser One", "courage"},
    {"The present moment is where possibility meets reality.", "The Wiser One", "courage"},

    // Gratitude & Appreciation
    {"Gratitude transforms what we have into more than enough.", "The Wiser One", "gratitude"},
    {"In giving thanks, we open our hearts to receive even more.", "The Wiser One", "gratitude"},
    {"Appreciation is the seed from which contentment grows.", "The Wiser One", "gratitude"},
    {"Abundance flows to those who appreciate what they already have.", "The Wiser One", "gratitude"},
    {"Thankfulness is the melody that makes life's song complete.", "The Wiser One", "gratitude"},
    {"The richest harvests come from the most patient cultivation.", "The Wiser One", "gratitude"},
    {"Harvest time reminds us to reap what we have sown with gratitude.", "The Wiser One", "gratitude"},
    {"Joy is found not in the destination but in the presence of the journey.", "The Wiser One", "gratitude"},
    {"What you nurture with attention grows; choose your focus wisely.", "The Wiser One", "gratitude"},
    {"In the garden of the mind, gratitude is the sunshine that helps everything grow.", "The Wiser One", "gratitude"},

    // Change & Impermanence
    {"Letting go is not giving up; it is making room for what comes next.", "The Wiser One", "change"},
    {"The beauty of autumn lies in its graceful release of what was.", "The Wiser One", "change"},
    {"The leaves that fall today become the nourishment of tomorrow.", "The Wiser One", "change"},
    {"In the gathering dusk, we learn to appreciate the light we carry within.", "The Wiser One", "change"},
    {"The shadows teach us to value the presence of light.", "The Wiser One", "change"},
    {"Change is the artist that paints the landscape of our lives.", "The Wiser One", "change"},
    {"Every ending writes the opening chapter of something new.", "The Wiser One", "change"},
    {"Endings are simply doorways to new beginnings.", "The Wiser One", "change"},
    {"As the year closes, we carry forward the lessons that shaped us.", "The Wiser One", "change"},
    {"With every sunset of a year comes the promise of a new dawn.", "The Wiser One", "change"},

    // Hope & Inspiration
    {"Hope is the star that guides us through the longest nights.", "The Wiser One", "hope"},
    {"The stillness of winter invites us to nurture our inner flame.", "The Wiser One", "hope"},
    {"The magic of the season lives in hearts willing to believe.", "The Wiser One", "hope"},
    {"Remembrance is the bridge that keeps us connected to what matters.", "The Wiser One", "hope"},
    {"The quiet before winter teaches us the value of introspection.", "The Wiser One", "hope"},
    {"The ripest fruit is born from the tree that weathered the storm.", "The Wiser One", "hope"},
    {"The golden hour teaches us that beauty often lies in transitions.", "The Wiser One", "hope"},
    {"The strongest roots grow in the soil enriched by past experiences.", "The Wiser One", "hope"},
    {"The longest day teaches us that even abundance has its limits.", "The Wiser One", "hope"},
    {"Embrace the warmth of ambition tempered by the coolness of wisdom.", "The Wiser One", "hope"},
}};
// clang-format on

}  // namespace

QuoteManager::QuoteManager()
    : m_connectionName(QUuid::createUuid().toString())
    , m_fallbackQuote{0, QObject::tr("Every moment is a fresh beginning."), QObject::tr("The Wiser One"), {}}
{
    if (!initializeDatabase()) {
        ErrorLogger::instance().log(
            QStringLiteral("QuoteManager.cpp"),
            QStringLiteral("QuoteManager"),
            QStringLiteral("Failed to initialize database"));
    }
}

QuoteManager::~QuoteManager()
{
    if (m_database.isOpen()) {
        m_database.close();
    }
    QSqlDatabase::removeDatabase(m_connectionName);
}

QString QuoteManager::getDatabasePath() const
{
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);
    return QDir(dataDir).filePath(QStringLiteral("quotes.db"));
}

bool QuoteManager::initializeDatabase()
{
    m_database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    m_database.setDatabaseName(getDatabasePath());

    if (!m_database.open()) {
        ErrorLogger::instance().log(
            QStringLiteral("QuoteManager.cpp"),
            QStringLiteral("initializeDatabase"),
            QStringLiteral("Failed to open database: %1").arg(m_database.lastError().text()));
        return false;
    }

    // Enable WAL mode for better concurrent performance
    QSqlQuery pragma(m_database);
    pragma.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    pragma.exec(QStringLiteral("PRAGMA synchronous=NORMAL"));

    if (!createSchema()) {
        return false;
    }

    // Seed initial quotes if database is empty
    if (quoteCount() == 0) {
        if (!seedInitialQuotes()) {
            return false;
        }
    }

    return true;
}

bool QuoteManager::createSchema()
{
    QSqlQuery query(m_database);

    // Create quotes table
    if (!query.exec(QStringLiteral(
            "CREATE TABLE IF NOT EXISTS quotes ("
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  text TEXT NOT NULL UNIQUE,"
            "  author TEXT DEFAULT 'The Wiser One',"
            "  category TEXT,"
            "  created_at TEXT DEFAULT CURRENT_TIMESTAMP"
            ")"))) {
        ErrorLogger::instance().log(
            QStringLiteral("QuoteManager.cpp"),
            QStringLiteral("createSchema"),
            QStringLiteral("Failed to create quotes table: %1").arg(query.lastError().text()));
        return false;
    }

    // Create index on category for filtering
    query.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_category ON quotes(category)"));

    return true;
}

bool QuoteManager::seedInitialQuotes()
{
    QSqlQuery query(m_database);

    if (!m_database.transaction()) {
        return false;
    }

    query.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO quotes (text, author, category) VALUES (?, ?, ?)"));

    for (const auto& [text, author, category] : INITIAL_QUOTES) {
        query.addBindValue(QString::fromUtf8(text));
        query.addBindValue(QString::fromUtf8(author));
        query.addBindValue(QString::fromUtf8(category));

        if (!query.exec()) {
            m_database.rollback();
            ErrorLogger::instance().log(
                QStringLiteral("QuoteManager.cpp"),
                QStringLiteral("seedInitialQuotes"),
                QStringLiteral("Failed to insert quote: %1").arg(query.lastError().text()));
            return false;
        }
    }

    m_cachedCount = -1;  // Invalidate count cache
    m_idsLoaded = false;  // Invalidate ID cache
    return m_database.commit();
}

std::int64_t QuoteManager::quoteCount() const
{
    if (m_cachedCount >= 0) {
        return m_cachedCount;
    }

    QSqlQuery query(m_database);
    if (query.exec(QStringLiteral("SELECT COUNT(*) FROM quotes")) && query.next()) {
        m_cachedCount = query.value(0).toLongLong();
        return m_cachedCount;
    }
    return 0;
}

bool QuoteManager::hasQuotes() const
{
    return quoteCount() > 0;
}

std::int64_t QuoteManager::getRandomId() const
{
    const auto count = quoteCount();
    if (count == 0) {
        return 0;
    }

    // Load IDs into cache if not already done
    if (!m_idsLoaded) {
        m_cachedIds.clear();
        QSqlQuery query(m_database);
        if (query.exec(QStringLiteral("SELECT id FROM quotes ORDER BY id"))) {
            while (query.next()) {
                m_cachedIds.push_back(query.value(0).toLongLong());
            }
        }
        m_idsLoaded = true;
    }

    if (m_cachedIds.empty()) {
        return 0;
    }

    // Fast O(1) random selection from cached IDs
    const int maxAttempts = 10;
    for (int attempt = 0; attempt < maxAttempts; ++attempt) {
        const auto randomIndex = QRandomGenerator::global()->bounded(static_cast<quint32>(m_cachedIds.size()));
        const auto randomId = m_cachedIds[randomIndex];

        if (randomId != m_lastId || m_cachedIds.size() == 1) {
            return randomId;
        }
    }

    // Fallback: return any ID (better than none)
    const auto randomIndex = QRandomGenerator::global()->bounded(static_cast<quint32>(m_cachedIds.size()));
    return m_cachedIds[randomIndex];
}

std::optional<Quote> QuoteManager::fetchQuoteById(std::int64_t id) const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT id, text, author, category FROM quotes WHERE id = ?"));
    query.addBindValue(static_cast<qlonglong>(id));

    if (query.exec() && query.next()) {
        return Quote{
            .id = query.value(0).toLongLong(),
            .text = query.value(1).toString(),
            .author = query.value(2).toString(),
            .category = query.value(3).toString()
        };
    }
    return std::nullopt;
}

Quote QuoteManager::getRandomQuote()
{
    auto result = tryGetRandomQuote();
    return result.value_or(m_fallbackQuote);
}

QuoteManager::QuoteResult QuoteManager::tryGetRandomQuote()
{
    if (!hasQuotes()) {
        return std::unexpected(QuoteError::EmptyCollection);
    }

    const auto id = getRandomId();
    if (id == 0) {
        return std::unexpected(QuoteError::DatabaseError);
    }

    auto quote = fetchQuoteById(id);
    if (!quote) {
        return std::unexpected(QuoteError::DatabaseError);
    }

    m_lastId = id;
    return *quote;
}

QuoteManager::QuoteResult QuoteManager::getRandomQuoteByCategory(const QString& category)
{
    // First get count for this category
    QSqlQuery countQuery(m_database);
    countQuery.prepare(QStringLiteral("SELECT COUNT(*) FROM quotes WHERE category = ?"));
    countQuery.addBindValue(category);

    if (!countQuery.exec() || !countQuery.next()) {
        return std::unexpected(QuoteError::DatabaseError);
    }

    const auto count = countQuery.value(0).toLongLong();
    if (count == 0) {
        return std::unexpected(QuoteError::EmptyCollection);
    }

    // Use OFFSET with random index instead of ORDER BY RANDOM()
    const auto randomOffset = QRandomGenerator::global()->bounded(static_cast<quint32>(count));

    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT id, text, author, category FROM quotes "
        "WHERE category = ? LIMIT 1 OFFSET ?"));
    query.addBindValue(category);
    query.addBindValue(static_cast<qlonglong>(randomOffset));

    if (query.exec() && query.next()) {
        return Quote{
            .id = query.value(0).toLongLong(),
            .text = query.value(1).toString(),
            .author = query.value(2).toString(),
            .category = query.value(3).toString()
        };
    }

    return std::unexpected(QuoteError::DatabaseError);
}

QStringList QuoteManager::categories() const
{
    QStringList result;
    QSqlQuery query(m_database);

    if (query.exec(QStringLiteral("SELECT DISTINCT category FROM quotes WHERE category IS NOT NULL ORDER BY category"))) {
        while (query.next()) {
            result.append(query.value(0).toString());
        }
    }

    return result;
}
