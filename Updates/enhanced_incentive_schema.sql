-- ===============================================
-- Enhanced Incentive System Database Schema
-- Smart notifications, priority updates, personalized alerts
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- User Interest Tracking for Personalized Notifications
CREATE TABLE UserInterests (
    UserID VARCHAR(100) NOT NULL,
    InterestType ENUM('category', 'author', 'publisher', 'keyword', 'isbn_pattern') NOT NULL,
    InterestValue VARCHAR(200) NOT NULL,
    InterestStrength DECIMAL(3,2) DEFAULT 1.0, -- 0.0 to 1.0 confidence
    NotificationEnabled BOOLEAN DEFAULT TRUE,
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastMatched TIMESTAMP NULL,
    MatchCount INTEGER DEFAULT 0,
    
    PRIMARY KEY (UserID, InterestType, InterestValue),
    INDEX idx_user_interests (UserID),
    INDEX idx_interest_type (InterestType),
    INDEX idx_notification_enabled (NotificationEnabled)
);

-- Smart Notification Queue
CREATE TABLE NotificationQueue (
    NotificationID INTEGER NOT NULL AUTO_INCREMENT,
    UserID VARCHAR(100) NOT NULL,
    NotificationType ENUM('new_book_match', 'recommendation', 'database_update', 'tier_upgrade', 'limit_warning') NOT NULL,
    Priority ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal',
    
    -- Notification content
    Title VARCHAR(200) NOT NULL,
    Message TEXT NOT NULL,
    ActionURL VARCHAR(500),
    ActionText VARCHAR(100),
    
    -- Targeting data
    BookID INTEGER NULL,
    CategoryPath VARCHAR(200) NULL,
    InterestMatchScore DECIMAL(3,2) NULL,
    
    -- Delivery tracking
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ScheduledDelivery TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    DeliveredDate TIMESTAMP NULL,
    DeliveryMethod ENUM('email', 'in_app', 'push', 'sms') DEFAULT 'email',
    ReadDate TIMESTAMP NULL,
    ClickedDate TIMESTAMP NULL,
    
    -- User tier at time of notification
    UserTierAtCreation ENUM('basic', 'connected', 'premium', 'vip') NOT NULL,
    
    PRIMARY KEY (NotificationID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE SET NULL,
    
    INDEX idx_notification_user (UserID),
    INDEX idx_notification_priority (Priority),
    INDEX idx_notification_scheduled (ScheduledDelivery),
    INDEX idx_notification_type (NotificationType),
    INDEX idx_notification_tier (UserTierAtCreation)
);

-- Priority Database Update Tracking
CREATE TABLE DatabaseUpdateEvents (
    UpdateEventID INTEGER NOT NULL AUTO_INCREMENT,
    UpdateType ENUM('book_addition', 'metadata_update', 'category_addition', 'bulk_import') NOT NULL,
    UpdateDescription TEXT,
    
    -- Update timing by tier
    BasicTierReleaseTime TIMESTAMP NULL,        -- When basic users get it
    ConnectedTierReleaseTime TIMESTAMP NULL,    -- When connected users get it  
    PremiumTierReleaseTime TIMESTAMP NULL,      -- When premium users get it
    VIPTierReleaseTime TIMESTAMP NULL,          -- When VIP users get it (earliest)
    
    -- Update metadata
    BooksAffected INTEGER DEFAULT 0,
    CategoriesAffected INTEGER DEFAULT 0,
    ProcessingStarted TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessingCompleted TIMESTAMP NULL,
    UpdateStatus ENUM('processing', 'staged', 'released', 'failed') DEFAULT 'processing',
    
    PRIMARY KEY (UpdateEventID),
    INDEX idx_update_type (UpdateType),
    INDEX idx_update_status (UpdateStatus),
    INDEX idx_tier_release_times (VIPTierReleaseTime, PremiumTierReleaseTime, ConnectedTierReleaseTime, BasicTierReleaseTime)
);

-- User-Specific Database Update Access
CREATE TABLE UserDatabaseAccess (
    UserID VARCHAR(100) NOT NULL,
    UpdateEventID INTEGER NOT NULL,
    AccessGrantedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UserTierAtGrant ENUM('basic', 'connected', 'premium', 'vip') NOT NULL,
    AccessType ENUM('early_access', 'regular_access', 'delayed_access') NOT NULL,
    NotificationSent BOOLEAN DEFAULT FALSE,
    
    PRIMARY KEY (UserID, UpdateEventID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (UpdateEventID) REFERENCES DatabaseUpdateEvents(UpdateEventID) ON DELETE CASCADE,
    
    INDEX idx_user_access (UserID),
    INDEX idx_update_access (UpdateEventID),
    INDEX idx_access_type (AccessType)
);

-- Enhanced Usage Tracking with Rate Limiting
CREATE TABLE UserUsageDetailed (
    UserID VARCHAR(100) NOT NULL,
    UsageDate DATE NOT NULL,
    
    -- Download tracking
    DownloadsToday INTEGER DEFAULT 0,
    DownloadBytesToday BIGINT DEFAULT 0,
    LastDownloadTime TIMESTAMP NULL,
    DownloadSpeedLimitMbps DECIMAL(5,2) DEFAULT 1.0,
    
    -- Search tracking
    SearchesToday INTEGER DEFAULT 0,
    AdvancedSearchesToday INTEGER DEFAULT 0,
    LastSearchTime TIMESTAMP NULL,
    
    -- Feature usage
    RecommendationsViewed INTEGER DEFAULT 0,
    NotificationsReceived INTEGER DEFAULT 0,
    NotificationsClicked INTEGER DEFAULT 0,
    
    -- Limit hit tracking
    DownloadLimitHits INTEGER DEFAULT 0,
    SearchLimitHits INTEGER DEFAULT 0,
    UpgradePromptsShown INTEGER DEFAULT 0,
    UpgradeClicks INTEGER DEFAULT 0,
    
    PRIMARY KEY (UserID, UsageDate),
    INDEX idx_usage_user (UserID),
    INDEX idx_usage_date (UsageDate),
    INDEX idx_limit_hits (DownloadLimitHits, SearchLimitHits)
);

-- Smart Recommendation Engine Data
CREATE TABLE BookRecommendations (
    RecommendationID INTEGER NOT NULL AUTO_INCREMENT,
    UserID VARCHAR(100) NOT NULL,
    BookID INTEGER NOT NULL,
    RecommendationType ENUM('interest_match', 'similar_users', 'trending', 'category_exploration') NOT NULL,
    RecommendationScore DECIMAL(4,3) NOT NULL, -- 0.0 to 1.0
    
    -- Recommendation basis
    BasedOnBooks JSON, -- Array of BookIDs that led to this recommendation
    BasedOnInterests JSON, -- Array of interests that match
    RecommendationReason TEXT,
    
    -- Performance tracking
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ShowDate TIMESTAMP NULL,
    ClickDate TIMESTAMP NULL,
    DownloadDate TIMESTAMP NULL,
    UserRating DECIMAL(2,1) NULL, -- User feedback on recommendation quality
    
    PRIMARY KEY (RecommendationID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_recommendations_user (UserID),
    INDEX idx_recommendations_book (BookID),
    INDEX idx_recommendations_score (RecommendationScore),
    INDEX idx_recommendations_type (RecommendationType)
);

-- Upgrade Prompt Tracking
CREATE TABLE UpgradePrompts (
    PromptID INTEGER NOT NULL AUTO_INCREMENT,
    UserID VARCHAR(100) NOT NULL,
    PromptTrigger ENUM('download_limit', 'search_limit', 'feature_access', 'speed_limit', 'notification_opportunity') NOT NULL,
    CurrentTier ENUM('basic', 'connected', 'premium', 'vip') NOT NULL,
    RecommendedTier ENUM('connected', 'premium', 'vip') NOT NULL,
    
    -- Prompt content
    PromptTitle VARCHAR(200),
    PromptMessage TEXT,
    IncentiveOffered TEXT,
    
    -- User response
    PromptShownDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UserAction ENUM('dismissed', 'clicked', 'upgraded', 'deferred') NULL,
    ActionDate TIMESTAMP NULL,
    PermissionsGranted JSON, -- Which permissions they enabled
    
    -- A/B testing
    PromptVariant VARCHAR(50) DEFAULT 'default',
    
    PRIMARY KEY (PromptID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    
    INDEX idx_prompts_user (UserID),
    INDEX idx_prompts_trigger (PromptTrigger),
    INDEX idx_prompts_response (UserAction),
    INDEX idx_prompts_variant (PromptVariant)
);

-- Real-time Notification Templates
CREATE TABLE NotificationTemplates (
    TemplateID INTEGER NOT NULL AUTO_INCREMENT,
    TemplateName VARCHAR(100) NOT NULL,
    NotificationType ENUM('new_book_match', 'recommendation', 'database_update', 'tier_upgrade', 'limit_warning') NOT NULL,
    RequiredTier ENUM('basic', 'connected', 'premium', 'vip') DEFAULT 'basic',
    
    -- Template content (with placeholders)
    SubjectTemplate VARCHAR(200),
    MessageTemplate TEXT,
    ActionButtonText VARCHAR(100),
    
    -- Targeting rules
    TargetingRules JSON, -- Conditions for when to use this template
    
    -- Performance tracking
    TimesUsed INTEGER DEFAULT 0,
    AvgOpenRate DECIMAL(4,3) DEFAULT 0.0,
    AvgClickRate DECIMAL(4,3) DEFAULT 0.0,
    
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (TemplateID),
    INDEX idx_templates_type (NotificationType),
    INDEX idx_templates_tier (RequiredTier),
    INDEX idx_templates_active (IsActive)
);

-- =============================================
-- STORED PROCEDURES FOR SMART NOTIFICATIONS
-- =============================================

DELIMITER //

-- Generate Personalized Book Notifications
CREATE PROCEDURE GenerateBookNotifications(IN p_BookID INTEGER)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_user_id VARCHAR(100);
    DECLARE v_interest_value VARCHAR(200);
    DECLARE v_match_score DECIMAL(3,2);
    DECLARE v_user_tier ENUM('basic', 'connected', 'premium', 'vip');
    DECLARE v_notification_priority ENUM('low', 'normal', 'high', 'urgent');
    
    -- Get book details for matching
    DECLARE v_book_title VARCHAR(500);
    DECLARE v_book_author VARCHAR(300);
    DECLARE v_book_category VARCHAR(200);
    DECLARE v_book_publisher VARCHAR(200);
    
    -- Cursor for users with matching interests
    DECLARE user_cursor CURSOR FOR
        SELECT DISTINCT ui.UserID, ui.InterestValue, 
               CASE ui.InterestType
                   WHEN 'category' THEN 0.9
                   WHEN 'author' THEN 0.8
                   WHEN 'publisher' THEN 0.6
                   WHEN 'keyword' THEN 0.7
                   ELSE 0.5
               END as MatchScore,
               uat.AccessTier
        FROM UserInterests ui
        JOIN UserAccessTiers uat ON ui.UserID = uat.UserID
        JOIN Books b ON b.BookID = p_BookID
        WHERE ui.NotificationEnabled = TRUE
        AND (
            (ui.InterestType = 'category' AND b.PrimaryCategory LIKE CONCAT('%', ui.InterestValue, '%'))
            OR (ui.InterestType = 'author' AND b.Author LIKE CONCAT('%', ui.InterestValue, '%'))  
            OR (ui.InterestType = 'publisher' AND b.Publisher LIKE CONCAT('%', ui.InterestValue, '%'))
            OR (ui.InterestType = 'keyword' AND (b.Title LIKE CONCAT('%', ui.InterestValue, '%') OR b.Description LIKE CONCAT('%', ui.InterestValue, '%')))
        );
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Get book details
    SELECT Title, Author, Publisher INTO v_book_title, v_book_author, v_book_publisher
    FROM Books WHERE BookID = p_BookID;
    
    -- Generate notifications for matching users
    OPEN user_cursor;
    
    read_loop: LOOP
        FETCH user_cursor INTO v_user_id, v_interest_value, v_match_score, v_user_tier;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Determine notification priority based on tier and match score
        SET v_notification_priority = CASE
            WHEN v_user_tier = 'vip' AND v_match_score >= 0.8 THEN 'urgent'
            WHEN v_user_tier IN ('premium', 'vip') AND v_match_score >= 0.7 THEN 'high'
            WHEN v_user_tier IN ('connected', 'premium', 'vip') THEN 'normal'
            ELSE 'low'
        END;
        
        -- Only send notifications to connected+ users
        IF v_user_tier != 'basic' THEN
            INSERT INTO NotificationQueue (
                UserID, NotificationType, Priority, Title, Message, BookID,
                InterestMatchScore, UserTierAtCreation, ScheduledDelivery
            ) VALUES (
                v_user_id, 
                'new_book_match',
                v_notification_priority,
                CONCAT('📚 New ', v_interest_value, ' book available!'),
                CONCAT('\"', v_book_title, '\" by ', v_book_author, ' matches your interests and is ready for download.'),
                p_BookID,
                v_match_score,
                v_user_tier,
                CASE v_user_tier
                    WHEN 'vip' THEN NOW()
                    WHEN 'premium' THEN DATE_ADD(NOW(), INTERVAL 1 HOUR)
                    WHEN 'connected' THEN DATE_ADD(NOW(), INTERVAL 2 HOUR)
                    ELSE DATE_ADD(NOW(), INTERVAL 1 DAY)
                END
            );
            
            -- Update interest match tracking
            UPDATE UserInterests 
            SET LastMatched = NOW(), MatchCount = MatchCount + 1
            WHERE UserID = v_user_id AND InterestValue = v_interest_value;
        END IF;
        
    END LOOP;
    
    CLOSE user_cursor;
    
END //

-- Check and Generate Upgrade Prompts
CREATE PROCEDURE CheckUpgradePrompts(IN p_UserID VARCHAR(100))
BEGIN
    DECLARE v_current_tier ENUM('basic', 'connected', 'premium', 'vip');
    DECLARE v_downloads_today INTEGER;
    DECLARE v_searches_today INTEGER;
    DECLARE v_download_limit INTEGER;
    DECLARE v_search_limit INTEGER;
    DECLARE v_prompt_count_today INTEGER;
    
    -- Get current user status
    SELECT uat.AccessTier, uat.DailyDownloadLimit, uat.DailySearchLimit,
           COALESCE(uud.DownloadsToday, 0), COALESCE(uud.SearchesToday, 0)
    INTO v_current_tier, v_download_limit, v_search_limit, v_downloads_today, v_searches_today
    FROM UserAccessTiers uat
    LEFT JOIN UserUsageDetailed uud ON uat.UserID = uud.UserID AND uud.UsageDate = CURRENT_DATE
    WHERE uat.UserID = p_UserID;
    
    -- Check how many prompts shown today
    SELECT COUNT(*) INTO v_prompt_count_today
    FROM UpgradePrompts
    WHERE UserID = p_UserID AND DATE(PromptShownDate) = CURRENT_DATE;
    
    -- Don't spam with prompts (max 2 per day)
    IF v_prompt_count_today < 2 THEN
        
        -- Check for download limit hit
        IF v_downloads_today >= v_download_limit AND v_current_tier != 'vip' THEN
            INSERT INTO UpgradePrompts (
                UserID, PromptTrigger, CurrentTier, RecommendedTier,
                PromptTitle, PromptMessage, IncentiveOffered
            ) VALUES (
                p_UserID, 'download_limit', v_current_tier,
                CASE v_current_tier
                    WHEN 'basic' THEN 'connected'
                    WHEN 'connected' THEN 'premium'
                    ELSE 'vip'
                END,
                '⏰ Daily Download Limit Reached!',
                CONCAT('You''ve hit your ', v_download_limit, ' download limit. Upgrade for more!'),
                CASE v_current_tier
                    WHEN 'basic' THEN 'Enable newsletter + book alerts for 5 downloads/day'
                    WHEN 'connected' THEN 'Add recommendations permission for 15 downloads/day'
                    ELSE 'Full VIP access for unlimited downloads'
                END
            );
        END IF;
        
        -- Check for search limit hit  
        IF v_searches_today >= v_search_limit AND v_current_tier != 'vip' THEN
            INSERT INTO UpgradePrompts (
                UserID, PromptTrigger, CurrentTier, RecommendedTier,
                PromptTitle, PromptMessage, IncentiveOffered
            ) VALUES (
                p_UserID, 'search_limit', v_current_tier,
                CASE v_current_tier
                    WHEN 'basic' THEN 'connected'
                    WHEN 'connected' THEN 'premium'
                    ELSE 'vip'
                END,
                '🔍 Search Limit Reached!',
                CONCAT('You''ve used all ', v_search_limit, ' searches today. Want more?'),
                'Upgrade for unlimited searches and advanced filters!'
            );
        END IF;
        
    END IF;
    
END //

DELIMITER ;

-- =============================================
-- INITIALIZATION DATA FOR ENHANCED FEATURES
-- =============================================

-- Sample notification templates
INSERT INTO NotificationTemplates (TemplateName, NotificationType, RequiredTier, SubjectTemplate, MessageTemplate, ActionButtonText) VALUES
('New Book Match - Basic', 'new_book_match', 'connected', 
 '📚 New {{interest}} book: {{book_title}}',
 'Great news! "{{book_title}}" by {{book_author}} just arrived and matches your {{interest}} interests. Available for immediate download!',
 'Download Now'),

('VIP Early Access', 'new_book_match', 'vip',
 '👑 VIP Early Access: {{book_title}}',
 'As a VIP member, you get first access to "{{book_title}}" - 2 hours before other users! This {{interest}} book has a {{match_score}}% match with your preferences.',
 'Download First'),

('Recommendation High Match', 'recommendation', 'connected',
 '🎯 Perfect match: {{book_title}}',
 'Our AI found "{{book_title}}" for you! Based on {{similar_books}}, this has a {{match_score}}% compatibility with your reading preferences.',
 'View Recommendation'),

('Database Update VIP', 'database_update', 'vip',
 '⚡ Priority Update: {{update_count}} new books available',
 'Your VIP access grants immediate availability to {{update_count}} new books, including {{featured_book}}. Other users will get access in {{delay_hours}} hours.',
 'Browse New Books');

-- Sample user interests (for testing)
INSERT INTO UserInterests (UserID, InterestType, InterestValue, InterestStrength, NotificationEnabled) VALUES
('user123', 'category', 'Programming', 1.0, TRUE),
('user123', 'author', 'O''Reilly', 0.8, TRUE),
('user123', 'keyword', 'Python', 0.9, TRUE),
('user456', 'category', 'Science', 0.7, TRUE),
('user456', 'publisher', 'MIT Press', 0.8, TRUE);

/*
ENHANCED FEATURES THIS SCHEMA ENABLES:

1. **Smart Interest Matching**:
   - Track user interests across categories, authors, keywords
   - Generate personalized notifications when matching books arrive
   - Calculate match scores for relevance ranking

2. **Tiered Database Updates**:
   - VIP users get immediate access to new books
   - Connected users get 1-2 hour early access
   - Basic users get standard access timing
   - Track and notify about update availability by tier

3. **Intelligent Upgrade Prompts**:
   - Trigger upgrade suggestions when users hit limits
   - Personalize prompts based on usage patterns
   - A/B test different prompt variants
   - Track conversion rates and user responses

4. **Real-time Notification System**:
   - Queue-based notification delivery
   - Priority routing based on user tier and match score
   - Template-driven message generation
   - Multi-channel delivery (email, in-app, push)

5. **Advanced Analytics**:
   - Track notification engagement rates
   - Monitor upgrade prompt effectiveness
   - Analyze user interest evolution over time
   - Measure feature usage by tier

EXAMPLE WORKFLOWS:

1. **New Book Added**:
   CALL GenerateBookNotifications(new_book_id);
   → Automatically notifies interested users based on tier priority

2. **User Hits Download Limit**:
   CALL CheckUpgradePrompts(user_id);
   → Shows contextual upgrade prompt with specific benefits

3. **Database Update Process**:
   → VIP users get immediate access + notification
   → Premium users get 1-hour delay + notification
   → Connected users get 2-hour delay + notification
   → Basic users get standard timing

This creates a sophisticated, personalized experience that incentivizes upgrades through real value delivery!
*/