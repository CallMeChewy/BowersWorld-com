-- ===============================================
-- Community-Driven Library Platform Schema
-- User ratings, book requests, community curation
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS MyLibrary_Community 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE MyLibrary_Community;

-- =============================================
-- ENHANCED USER SYSTEM
-- =============================================

-- Comprehensive User Profiles
CREATE TABLE Users (
    UserID VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    Username VARCHAR(50),
    DisplayName VARCHAR(100),
    
    -- Profile information
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    Bio TEXT,
    AvatarURL VARCHAR(500),
    Location VARCHAR(100),
    Website VARCHAR(300),
    
    -- Reading preferences
    PreferredLanguages JSON, -- ['English', 'Spanish']
    PreferredCategories JSON, -- ['Programming', 'Science']
    ReadingLevel ENUM('beginner', 'intermediate', 'advanced', 'expert') DEFAULT 'intermediate',
    
    -- Community engagement
    CommunityRank ENUM('reader', 'contributor', 'curator', 'moderator', 'admin') DEFAULT 'reader',
    ReputationScore INTEGER DEFAULT 0,
    TotalRatingsGiven INTEGER DEFAULT 0,
    TotalRequestsMade INTEGER DEFAULT 0,
    TotalRequestsFulfilled INTEGER DEFAULT 0,
    
    -- Account status
    AccountStatus ENUM('active', 'suspended', 'banned', 'pending') DEFAULT 'active',
    EmailVerified BOOLEAN DEFAULT FALSE,
    ProfileComplete BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastLoginDate TIMESTAMP NULL,
    LastActivityDate TIMESTAMP NULL,
    ProfileUpdatedDate TIMESTAMP NULL,
    
    PRIMARY KEY (UserID),
    UNIQUE KEY UK_Users_Email (Email),
    UNIQUE KEY UK_Users_Username (Username),
    
    INDEX idx_users_reputation (ReputationScore),
    INDEX idx_users_rank (CommunityRank),
    INDEX idx_users_status (AccountStatus),
    INDEX idx_users_activity (LastActivityDate)
);

-- =============================================
-- BOOK RATING SYSTEM
-- =============================================

-- Individual User Ratings
CREATE TABLE BookRatings (
    RatingID INTEGER NOT NULL AUTO_INCREMENT,
    UserID VARCHAR(100) NOT NULL,
    BookID INTEGER NOT NULL,
    
    -- Rating details
    StarRating DECIMAL(2,1) NOT NULL CHECK (StarRating >= 1.0 AND StarRating <= 5.0),
    ReviewTitle VARCHAR(200),
    ReviewText TEXT,
    RecommendToOthers BOOLEAN DEFAULT TRUE,
    
    -- Reading experience
    ReadingStatus ENUM('want_to_read', 'currently_reading', 'completed', 'dnf') DEFAULT 'completed',
    ReadingStartDate DATE NULL,
    ReadingCompletedDate DATE NULL,
    ReadingDuration INTEGER NULL, -- Days spent reading
    
    -- Helpful metrics
    HelpfulVotes INTEGER DEFAULT 0,
    UnhelpfulVotes INTEGER DEFAULT 0,
    ReportCount INTEGER DEFAULT 0,
    
    -- Moderation
    IsModerated BOOLEAN DEFAULT FALSE,
    ModeratedBy VARCHAR(100) NULL,
    ModerationReason TEXT NULL,
    
    -- Timestamps
    RatingDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (RatingID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (ModeratedBy) REFERENCES Users(UserID) ON DELETE SET NULL,
    
    UNIQUE KEY UK_UserBook_Rating (UserID, BookID),
    INDEX idx_ratings_book (BookID),
    INDEX idx_ratings_star (StarRating),
    INDEX idx_ratings_date (RatingDate),
    INDEX idx_ratings_helpful (HelpfulVotes),
    INDEX idx_ratings_status (ReadingStatus)
);

-- Aggregated Book Rating Statistics
CREATE TABLE BookRatingStats (
    BookID INTEGER NOT NULL,
    
    -- Overall statistics
    TotalRatings INTEGER DEFAULT 0,
    AverageRating DECIMAL(3,2) DEFAULT 0.0,
    WeightedRating DECIMAL(3,2) DEFAULT 0.0, -- Weighted by user reputation
    
    -- Rating distribution
    FiveStarCount INTEGER DEFAULT 0,
    FourStarCount INTEGER DEFAULT 0,
    ThreeStarCount INTEGER DEFAULT 0,
    TwoStarCount INTEGER DEFAULT 0,
    OneStarCount INTEGER DEFAULT 0,
    
    -- Reading patterns
    AverageReadingDuration INTEGER DEFAULT 0,
    CompletionRate DECIMAL(4,3) DEFAULT 0.0, -- Percentage who completed vs DNF
    RecommendationRate DECIMAL(4,3) DEFAULT 0.0, -- Percentage who recommend
    
    -- Quality indicators
    ReviewCount INTEGER DEFAULT 0,
    QualityScore DECIMAL(4,3) DEFAULT 0.0, -- Based on review quality, helpfulness
    TrendingScore DECIMAL(6,3) DEFAULT 0.0, -- Recent activity boost
    
    -- Last updated
    LastCalculated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    INDEX idx_rating_stats_avg (AverageRating),
    INDEX idx_rating_stats_total (TotalRatings),
    INDEX idx_rating_stats_trending (TrendingScore),
    INDEX idx_rating_stats_quality (QualityScore)
);

-- =============================================
-- BOOK REQUEST/SUGGESTION SYSTEM
-- =============================================

-- User Book Requests
CREATE TABLE BookRequests (
    RequestID INTEGER NOT NULL AUTO_INCREMENT,
    RequesterID VARCHAR(100) NOT NULL,
    
    -- Request details
    RequestType ENUM('specific_book', 'topic_suggestion', 'author_works', 'series_completion') NOT NULL,
    Priority ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal',
    
    -- Book identification
    RequestedTitle VARCHAR(500),
    RequestedAuthor VARCHAR(300),
    RequestedISBN VARCHAR(20),
    RequestedPublisher VARCHAR(200),
    RequestedYear INTEGER,
    RequestedEdition VARCHAR(100),
    
    -- Additional context
    RequestReason TEXT, -- Why they want this book
    SuggestedCategory VARCHAR(200),
    SuggestedSubjects TEXT,
    AlternativeTitles TEXT, -- Other acceptable versions
    
    -- External links/references
    AmazonURL VARCHAR(500),
    GoogleBooksURL VARCHAR(500),
    PublisherURL VARCHAR(500),
    OtherSources TEXT,
    
    -- Community support
    UpvoteCount INTEGER DEFAULT 0,
    DownvoteCount INTEGER DEFAULT 0,
    CommunityComments INTEGER DEFAULT 0,
    DuplicateOfRequestID INTEGER NULL, -- If this is a duplicate
    
    -- Processing status
    RequestStatus ENUM('pending', 'reviewing', 'approved', 'in_progress', 'acquired', 'rejected', 'duplicate') DEFAULT 'pending',
    StatusReason TEXT,
    AssignedTo VARCHAR(100) NULL, -- Staff member handling this
    
    -- Acquisition tracking
    EstimatedCost DECIMAL(8,2) NULL,
    ActualCost DECIMAL(8,2) NULL,
    AcquisitionMethod ENUM('purchase', 'donation', 'api_download', 'scan', 'already_owned') NULL,
    AcquisitionDate TIMESTAMP NULL,
    AcquisitionNotes TEXT,
    
    -- Timestamps
    RequestDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    ReviewedDate TIMESTAMP NULL,
    FulfilledDate TIMESTAMP NULL,
    
    PRIMARY KEY (RequestID),
    FOREIGN KEY (RequesterID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (AssignedTo) REFERENCES Users(UserID) ON DELETE SET NULL,
    FOREIGN KEY (DuplicateOfRequestID) REFERENCES BookRequests(RequestID) ON DELETE SET NULL,
    
    INDEX idx_requests_user (RequesterID),
    INDEX idx_requests_status (RequestStatus),
    INDEX idx_requests_priority (Priority),
    INDEX idx_requests_date (RequestDate),
    INDEX idx_requests_upvotes (UpvoteCount),
    INDEX idx_requests_assigned (AssignedTo),
    
    FULLTEXT INDEX ft_request_search (RequestedTitle, RequestedAuthor, RequestReason)
);

-- Community Voting on Requests
CREATE TABLE RequestVotes (
    VoteID INTEGER NOT NULL AUTO_INCREMENT,
    RequestID INTEGER NOT NULL,
    UserID VARCHAR(100) NOT NULL,
    VoteType ENUM('upvote', 'downvote') NOT NULL,
    VoteReason TEXT,
    VoteDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (VoteID),
    FOREIGN KEY (RequestID) REFERENCES BookRequests(RequestID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    
    UNIQUE KEY UK_User_Request_Vote (UserID, RequestID),
    INDEX idx_votes_request (RequestID),
    INDEX idx_votes_type (VoteType)
);

-- Comments on Book Requests
CREATE TABLE RequestComments (
    CommentID INTEGER NOT NULL AUTO_INCREMENT,
    RequestID INTEGER NOT NULL,
    UserID VARCHAR(100) NOT NULL,
    ParentCommentID INTEGER NULL, -- For threaded discussions
    
    CommentText TEXT NOT NULL,
    IsStaffResponse BOOLEAN DEFAULT FALSE,
    
    -- Community interaction
    HelpfulVotes INTEGER DEFAULT 0,
    ReportCount INTEGER DEFAULT 0,
    
    -- Moderation
    IsModerated BOOLEAN DEFAULT FALSE,
    ModeratedBy VARCHAR(100) NULL,
    ModerationReason TEXT NULL,
    
    CommentDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastEdited TIMESTAMP NULL,
    
    PRIMARY KEY (CommentID),
    FOREIGN KEY (RequestID) REFERENCES BookRequests(RequestID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (ParentCommentID) REFERENCES RequestComments(CommentID) ON DELETE CASCADE,
    FOREIGN KEY (ModeratedBy) REFERENCES Users(UserID) ON DELETE SET NULL,
    
    INDEX idx_comments_request (RequestID),
    INDEX idx_comments_user (UserID),
    INDEX idx_comments_parent (ParentCommentID),
    INDEX idx_comments_date (CommentDate)
);

-- =============================================
-- COMMUNITY CURATION & MODERATION
-- =============================================

-- Content Moderation Queue
CREATE TABLE ModerationQueue (
    ModerationID INTEGER NOT NULL AUTO_INCREMENT,
    ContentType ENUM('rating', 'review', 'request', 'comment', 'user_profile') NOT NULL,
    ContentID INTEGER NOT NULL, -- ID of the content being moderated
    ReportedBy VARCHAR(100) NOT NULL,
    
    ReportReason ENUM('spam', 'inappropriate', 'copyright', 'duplicate', 'false_information', 'harassment') NOT NULL,
    ReportDetails TEXT,
    
    ModerationStatus ENUM('pending', 'reviewed', 'approved', 'rejected', 'requires_action') DEFAULT 'pending',
    ModeratedBy VARCHAR(100) NULL,
    ModerationNotes TEXT,
    ActionTaken ENUM('none', 'content_removed', 'content_edited', 'user_warned', 'user_suspended') NULL,
    
    ReportDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ReviewedDate TIMESTAMP NULL,
    
    PRIMARY KEY (ModerationID),
    FOREIGN KEY (ReportedBy) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (ModeratedBy) REFERENCES Users(UserID) ON DELETE SET NULL,
    
    INDEX idx_moderation_type (ContentType),
    INDEX idx_moderation_status (ModerationStatus),
    INDEX idx_moderation_reason (ReportReason),
    INDEX idx_moderation_date (ReportDate)
);

-- User Reputation System
CREATE TABLE UserReputationEvents (
    EventID INTEGER NOT NULL AUTO_INCREMENT,
    UserID VARCHAR(100) NOT NULL,
    EventType ENUM('rating_given', 'helpful_review', 'request_fulfilled', 'quality_content', 'community_contribution', 'moderation_violation') NOT NULL,
    ReputationChange INTEGER NOT NULL, -- Can be positive or negative
    RelatedContentType ENUM('rating', 'review', 'request', 'comment') NULL,
    RelatedContentID INTEGER NULL,
    EventDescription TEXT,
    EventDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (EventID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    
    INDEX idx_reputation_user (UserID),
    INDEX idx_reputation_type (EventType),
    INDEX idx_reputation_date (EventDate)
);

-- =============================================
-- ENHANCED ANALYTICS & METRICS
-- =============================================

-- Popular Requests Analytics
CREATE TABLE PopularRequestsAnalytics (
    AnalyticsID INTEGER NOT NULL AUTO_INCREMENT,
    AnalyticsPeriod ENUM('daily', 'weekly', 'monthly') NOT NULL,
    PeriodDate DATE NOT NULL,
    
    -- Request patterns
    TotalRequestsSubmitted INTEGER DEFAULT 0,
    TotalRequestsFulfilled INTEGER DEFAULT 0,
    AverageRequestFulfillmentTime INTEGER DEFAULT 0, -- Days
    MostRequestedCategory VARCHAR(200),
    MostRequestedAuthor VARCHAR(300),
    
    -- Community engagement
    TotalCommunityVotes INTEGER DEFAULT 0,
    TotalCommunityComments INTEGER DEFAULT 0,
    ActiveRequesters INTEGER DEFAULT 0,
    
    -- Cost analysis
    TotalAcquisitionCost DECIMAL(10,2) DEFAULT 0.0,
    AverageCostPerBook DECIMAL(8,2) DEFAULT 0.0,
    ROIScore DECIMAL(6,3) DEFAULT 0.0, -- Return on investment based on downloads
    
    PRIMARY KEY (AnalyticsID),
    UNIQUE KEY UK_Period_Date (AnalyticsPeriod, PeriodDate),
    INDEX idx_analytics_period (AnalyticsPeriod),
    INDEX idx_analytics_date (PeriodDate)
);

-- Reading Behavior Analytics
CREATE TABLE ReadingBehaviorAnalytics (
    UserID VARCHAR(100) NOT NULL,
    AnalyticsPeriod ENUM('monthly', 'quarterly', 'yearly') NOT NULL,
    PeriodDate DATE NOT NULL,
    
    -- Reading statistics
    BooksDownloaded INTEGER DEFAULT 0,
    BooksRated INTEGER DEFAULT 0,
    BooksCompleted INTEGER DEFAULT 0,
    AverageRating DECIMAL(3,2) DEFAULT 0.0,
    
    -- Reading patterns
    FavoriteCategories JSON,
    FavoriteAuthors JSON,
    ReadingStreak INTEGER DEFAULT 0, -- Consecutive days with activity
    
    -- Community contribution
    HelpfulReviewsWritten INTEGER DEFAULT 0,
    RequestsSubmitted INTEGER DEFAULT 0,
    CommunityInteractions INTEGER DEFAULT 0,
    ReputationGained INTEGER DEFAULT 0,
    
    PRIMARY KEY (UserID, AnalyticsPeriod, PeriodDate),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    
    INDEX idx_reading_analytics_user (UserID),
    INDEX idx_reading_analytics_period (AnalyticsPeriod, PeriodDate)
);

-- Content Acquisition ROI Tracking
CREATE TABLE ContentROITracking (
    BookID INTEGER NOT NULL,
    
    -- Acquisition details
    AcquisitionCost DECIMAL(8,2) DEFAULT 0.0,
    AcquisitionDate TIMESTAMP,
    AcquisitionMethod ENUM('purchase', 'donation', 'api_download', 'scan', 'already_owned'),
    
    -- Usage metrics
    TotalDownloads INTEGER DEFAULT 0,
    UniqueDownloaders INTEGER DEFAULT 0,
    TotalRatings INTEGER DEFAULT 0,
    AverageRating DECIMAL(3,2) DEFAULT 0.0,
    
    -- Value calculation
    EstimatedValue DECIMAL(10,2) DEFAULT 0.0, -- Based on downloads, ratings, requests
    ROIScore DECIMAL(6,3) DEFAULT 0.0,
    PaybackPeriod INTEGER DEFAULT 0, -- Days to break even
    
    -- Request tracking
    WasRequested BOOLEAN DEFAULT FALSE,
    RequestID INTEGER NULL, -- Original request that led to acquisition
    RequestUpvotes INTEGER DEFAULT 0,
    
    LastCalculated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BookID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (RequestID) REFERENCES BookRequests(RequestID) ON DELETE SET NULL,
    
    INDEX idx_roi_score (ROIScore),
    INDEX idx_roi_cost (AcquisitionCost),
    INDEX idx_roi_downloads (TotalDownloads),
    INDEX idx_roi_requested (WasRequested)
);

-- =============================================
-- STORED PROCEDURES FOR COMMUNITY FEATURES
-- =============================================

DELIMITER //

-- Update Book Rating Statistics
CREATE PROCEDURE UpdateBookRatingStats(IN p_BookID INTEGER)
BEGIN
    DECLARE total_ratings INTEGER DEFAULT 0;
    DECLARE avg_rating DECIMAL(3,2) DEFAULT 0.0;
    DECLARE weighted_rating DECIMAL(3,2) DEFAULT 0.0;
    DECLARE completion_rate DECIMAL(4,3) DEFAULT 0.0;
    DECLARE recommend_rate DECIMAL(4,3) DEFAULT 0.0;
    
    -- Calculate basic statistics
    SELECT 
        COUNT(*),
        AVG(StarRating),
        AVG(StarRating * (1 + (u.ReputationScore / 1000))), -- Weight by user reputation
        AVG(CASE WHEN ReadingStatus = 'completed' THEN 1.0 ELSE 0.0 END),
        AVG(CASE WHEN RecommendToOthers THEN 1.0 ELSE 0.0 END)
    INTO total_ratings, avg_rating, weighted_rating, completion_rate, recommend_rate
    FROM BookRatings br
    JOIN Users u ON br.UserID = u.UserID
    WHERE br.BookID = p_BookID AND br.IsModerated = FALSE;
    
    -- Update or insert statistics
    INSERT INTO BookRatingStats (
        BookID, TotalRatings, AverageRating, WeightedRating, 
        CompletionRate, RecommendationRate,
        FiveStarCount, FourStarCount, ThreeStarCount, TwoStarCount, OneStarCount
    )
    SELECT 
        p_BookID, total_ratings, avg_rating, weighted_rating,
        completion_rate, recommend_rate,
        SUM(CASE WHEN StarRating >= 4.5 THEN 1 ELSE 0 END),
        SUM(CASE WHEN StarRating >= 3.5 AND StarRating < 4.5 THEN 1 ELSE 0 END),
        SUM(CASE WHEN StarRating >= 2.5 AND StarRating < 3.5 THEN 1 ELSE 0 END),
        SUM(CASE WHEN StarRating >= 1.5 AND StarRating < 2.5 THEN 1 ELSE 0 END),
        SUM(CASE WHEN StarRating < 1.5 THEN 1 ELSE 0 END)
    FROM BookRatings 
    WHERE BookID = p_BookID AND IsModerated = FALSE
    ON DUPLICATE KEY UPDATE
        TotalRatings = total_ratings,
        AverageRating = avg_rating,
        WeightedRating = weighted_rating,
        CompletionRate = completion_rate,
        RecommendationRate = recommend_rate,
        FiveStarCount = VALUES(FiveStarCount),
        FourStarCount = VALUES(FourStarCount),
        ThreeStarCount = VALUES(ThreeStarCount),
        TwoStarCount = VALUES(TwoStarCount),
        OneStarCount = VALUES(OneStarCount);
        
END //

-- Process Book Request
CREATE PROCEDURE ProcessBookRequest(
    IN p_RequestID INTEGER,
    IN p_ModeratorID VARCHAR(100),
    IN p_NewStatus ENUM('approved', 'rejected', 'duplicate'),
    IN p_StatusReason TEXT
)
BEGIN
    DECLARE v_requester_id VARCHAR(100);
    DECLARE v_reputation_change INTEGER DEFAULT 0;
    
    -- Get requester ID
    SELECT RequesterID INTO v_requester_id 
    FROM BookRequests 
    WHERE RequestID = p_RequestID;
    
    -- Update request status
    UPDATE BookRequests 
    SET RequestStatus = p_NewStatus,
        StatusReason = p_StatusReason,
        AssignedTo = p_ModeratorID,
        ReviewedDate = NOW()
    WHERE RequestID = p_RequestID;
    
    -- Award/deduct reputation based on decision
    SET v_reputation_change = CASE p_NewStatus
        WHEN 'approved' THEN 10
        WHEN 'rejected' THEN -2
        WHEN 'duplicate' THEN -1
        ELSE 0
    END;
    
    IF v_reputation_change != 0 THEN
        -- Update user reputation
        UPDATE Users 
        SET ReputationScore = ReputationScore + v_reputation_change
        WHERE UserID = v_requester_id;
        
        -- Log reputation event
        INSERT INTO UserReputationEvents (
            UserID, EventType, ReputationChange, 
            RelatedContentType, RelatedContentID, EventDescription
        ) VALUES (
            v_requester_id,
            CASE p_NewStatus
                WHEN 'approved' THEN 'quality_content'
                ELSE 'moderation_violation'
            END,
            v_reputation_change,
            'request',
            p_RequestID,
            CONCAT('Book request ', p_NewStatus, ': ', p_StatusReason)
        );
    END IF;
    
END //

-- Calculate User Reputation Score
CREATE PROCEDURE CalculateUserReputation(IN p_UserID VARCHAR(100))
BEGIN
    DECLARE total_reputation INTEGER DEFAULT 0;
    
    -- Sum all reputation events
    SELECT COALESCE(SUM(ReputationChange), 0) INTO total_reputation
    FROM UserReputationEvents
    WHERE UserID = p_UserID;
    
    -- Update user's reputation score
    UPDATE Users 
    SET ReputationScore = total_reputation
    WHERE UserID = p_UserID;
    
END //

DELIMITER ;

-- =============================================
-- SAMPLE DATA FOR TESTING
-- =============================================

-- Sample users
INSERT INTO Users (UserID, Email, Username, DisplayName, ReputationScore, CommunityRank) VALUES
('user001', 'alice@example.com', 'alice_reader', 'Alice Johnson', 150, 'contributor'),
('user002', 'bob@example.com', 'bob_coder', 'Bob Smith', 75, 'reader'),
('user003', 'carol@example.com', 'carol_curator', 'Carol Davis', 500, 'curator');

-- Sample book requests
INSERT INTO BookRequests (RequesterID, RequestType, RequestedTitle, RequestedAuthor, RequestReason, UpvoteCount) VALUES
('user001', 'specific_book', 'Clean Architecture', 'Robert C. Martin', 'Essential for software development team', 15),
('user002', 'topic_suggestion', 'Machine Learning with PyTorch', 'Various', 'Need more recent ML resources', 8),
('user003', 'author_works', 'Complete works', 'Donald Knuth', 'Missing volumes 4+ of TAOCP', 25);

/*
COMMUNITY PLATFORM FEATURES THIS ENABLES:

1. **User-Driven Content Curation**:
   - Users can request specific books
   - Community voting on requests
   - ROI tracking for acquisitions
   - Automatic duplicate detection

2. **Comprehensive Rating System**:
   - 5-star ratings with reviews
   - Reading status tracking
   - Weighted ratings by user reputation
   - Aggregated statistics for recommendations

3. **Community Engagement**:
   - User profiles with reputation scores
   - Comment threads on requests
   - Helpful/unhelpful voting on reviews
   - Community moderation system

4. **Advanced Analytics**:
   - ROI tracking on book acquisitions
   - Popular request analysis
   - Reading behavior patterns
   - Community health metrics

5. **Content Quality Assurance**:
   - Moderation queues for inappropriate content
   - Reputation-based content weighting
   - Automated spam detection
   - Community-driven quality control

BUSINESS VALUE:
- **Data-driven acquis