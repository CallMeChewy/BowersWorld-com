-- ===============================================
-- Community Contribution & Sharing Platform Schema
-- Members contribute books, expertise, and curation
-- Standard: AIDEV-PascalCase-1.8
-- Author: Herb Bowers - Project Himalaya
-- ===============================================

-- =============================================
-- CONTENT CONTRIBUTION SYSTEM
-- =============================================

-- Book Contributions from Community Members
CREATE TABLE BookContributions (
    ContributionID INTEGER NOT NULL AUTO_INCREMENT,
    ContributorID VARCHAR(100) NOT NULL,
    ContributionType ENUM('new_book', 'improved_metadata', 'cover_image', 'table_of_contents', 'book_description', 'category_suggestion') NOT NULL,
    
    -- Book identification
    BookID INTEGER NULL, -- NULL if new book, filled if improving existing
    ProposedTitle VARCHAR(500),
    ProposedAuthor VARCHAR(300),
    ProposedPublisher VARCHAR(200),
    ProposedISBN VARCHAR(20),
    ProposedYear INTEGER,
    
    -- Contribution details
    ContributionDescription TEXT,
    FileHash VARCHAR(128), -- For uploaded files
    FilePath VARCHAR(1000), -- Secure storage location
    FileSize BIGINT,
    OriginalFileName VARCHAR(500),
    
    -- Metadata contributions
    ProposedCategories JSON, -- Array of category suggestions
    ProposedTags JSON, -- Array of tag suggestions
    ProposedDescription TEXT,
    QualityNotes TEXT, -- Contributor's notes on quality/condition
    
    -- Legal compliance
    CopyrightStatus ENUM('public_domain', 'fair_use', 'permission_granted', 'owned_copy', 'unknown') NOT NULL,
    CopyrightNotes TEXT,
    SourceInformation TEXT, -- Where/how they obtained this
    
    -- Community validation
    UpvoteCount INTEGER DEFAULT 0,
    DownvoteCount INTEGER DEFAULT 0,
    QualityScore DECIMAL(3,2) DEFAULT 0.0, -- Community-assessed quality
    
    -- Processing status
    ContributionStatus ENUM('pending', 'under_review', 'approved', 'rejected', 'needs_revision', 'duplicate') DEFAULT 'pending',
    ReviewedBy VARCHAR(100) NULL,
    ReviewNotes TEXT,
    RejectionReason TEXT,
    
    -- Timestamps
    ContributionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ReviewedDate TIMESTAMP NULL,
    ApprovedDate TIMESTAMP NULL,
    
    -- Reward tracking
    RewardPoints INTEGER DEFAULT 0,
    RewardPaid BOOLEAN DEFAULT FALSE,
    
    PRIMARY KEY (ContributionID),
    FOREIGN KEY (ContributorID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (ReviewedBy) REFERENCES Users(UserID) ON DELETE SET NULL,
    
    INDEX idx_contributions_contributor (ContributorID),
    INDEX idx_contributions_book (BookID),
    INDEX idx_contributions_status (ContributionStatus),
    INDEX idx_contributions_type (ContributionType),
    INDEX idx_contributions_date (ContributionDate),
    
    FULLTEXT INDEX ft_contribution_search (ProposedTitle, ProposedAuthor, ContributionDescription)
);

-- Community Validation of Contributions
CREATE TABLE ContributionValidation (
    ValidationID INTEGER NOT NULL AUTO_INCREMENT,
    ContributionID INTEGER NOT NULL,
    ValidatorID VARCHAR(100) NOT NULL,
    ValidationType ENUM('quality_check', 'duplicate_check', 'copyright_review', 'metadata_accuracy', 'technical_review') NOT NULL,
    
    ValidationResult ENUM('approved', 'rejected', 'needs_revision') NOT NULL,
    ValidationNotes TEXT,
    ConfidenceLevel ENUM('low', 'medium', 'high') DEFAULT 'medium',
    
    -- Specific validation criteria
    QualityRating DECIMAL(2,1) NULL, -- 1.0 to 5.0 for quality
    IsDuplicate BOOLEAN DEFAULT FALSE,
    DuplicateOfBookID INTEGER NULL,
    CopyrightConcerns BOOLEAN DEFAULT FALSE,
    TechnicalIssues TEXT,
    
    ValidationDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (ValidationID),
    FOREIGN KEY (ContributionID) REFERENCES BookContributions(ContributionID) ON DELETE CASCADE,
    FOREIGN KEY (ValidatorID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (DuplicateOfBookID) REFERENCES Books(BookID) ON DELETE SET NULL,
    
    UNIQUE KEY UK_Contribution_Validator (ContributionID, ValidatorID),
    INDEX idx_validation_contribution (ContributionID),
    INDEX idx_validation_validator (ValidatorID),
    INDEX idx_validation_result (ValidationResult)
);

-- =============================================
-- COLLABORATIVE METADATA IMPROVEMENT
-- =============================================

-- Crowdsourced Metadata Improvements
CREATE TABLE MetadataImprovements (
    ImprovementID INTEGER NOT NULL AUTO_INCREMENT,
    BookID INTEGER NOT NULL,
    ContributorID VARCHAR(100) NOT NULL,
    ImprovementType ENUM('title_correction', 'author_addition', 'category_refinement', 'description_enhancement', 'tag_addition', 'error_correction') NOT NULL,
    
    -- Before/after values
    FieldName VARCHAR(100) NOT NULL,
    OldValue TEXT,
    NewValue TEXT NOT NULL,
    ChangeReason TEXT,
    
    -- Supporting evidence
    SourceReferences TEXT, -- URLs, book citations, etc.
    EvidenceFiles JSON, -- Array of uploaded evidence files
    
    -- Community consensus
    AgreeVotes INTEGER DEFAULT 0,
    DisagreeVotes INTEGER DEFAULT 0,
    NeutralVotes INTEGER DEFAULT 0,
    ExpertEndorsements INTEGER DEFAULT 0, -- Votes from high-reputation users
    
    -- Processing
    ImprovementStatus ENUM('proposed', 'under_discussion', 'accepted', 'rejected', 'superseded') DEFAULT 'proposed',
    AcceptedBy VARCHAR(100) NULL,
    AcceptanceDate TIMESTAMP NULL,
    ImplementedDate TIMESTAMP NULL,
    
    ProposalDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastDiscussionActivity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (ImprovementID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (ContributorID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (AcceptedBy) REFERENCES Users(UserID) ON DELETE SET NULL,
    
    INDEX idx_improvements_book (BookID),
    INDEX idx_improvements_contributor (ContributorID),
    INDEX idx_improvements_status (ImprovementStatus),
    INDEX idx_improvements_type (ImprovementType),
    INDEX idx_improvements_votes (AgreeVotes, DisagreeVotes)
);

-- Discussion Threads for Metadata Improvements
CREATE TABLE ImprovementDiscussions (
    DiscussionID INTEGER NOT NULL AUTO_INCREMENT,
    ImprovementID INTEGER NOT NULL,
    ParticipantID VARCHAR(100) NOT NULL,
    ParentDiscussionID INTEGER NULL, -- For threaded discussions
    
    MessageText TEXT NOT NULL,
    MessageType ENUM('comment', 'question', 'evidence', 'objection', 'support') DEFAULT 'comment',
    
    -- Attached files/references
    AttachedFiles JSON,
    ReferencedSources TEXT,
    
    -- Community interaction
    HelpfulVotes INTEGER DEFAULT 0,
    MessageDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastEdited TIMESTAMP NULL,
    
    PRIMARY KEY (DiscussionID),
    FOREIGN KEY (ImprovementID) REFERENCES MetadataImprovements(ImprovementID) ON DELETE CASCADE,
    FOREIGN KEY (ParticipantID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (ParentDiscussionID) REFERENCES ImprovementDiscussions(DiscussionID) ON DELETE CASCADE,
    
    INDEX idx_discussions_improvement (ImprovementID),
    INDEX idx_discussions_participant (ParticipantID),
    INDEX idx_discussions_parent (ParentDiscussionID),
    INDEX idx_discussions_date (MessageDate)
);

-- =============================================
-- COMMUNITY EXPERTISE & KNOWLEDGE SHARING
-- =============================================

-- Expert Knowledge Contributions
CREATE TABLE ExpertContributions (
    ExpertiseID INTEGER NOT NULL AUTO_INCREMENT,
    ExpertID VARCHAR(100) NOT NULL,
    ExpertiseType ENUM('book_summary', 'reading_guide', 'prerequisite_map', 'learning_path', 'practical_application', 'errata') NOT NULL,
    
    -- Subject matter
    BookID INTEGER NULL, -- Can be about specific book
    CategoryPath VARCHAR(500) NULL, -- Or about entire category
    TopicKeywords JSON, -- Array of related topics
    
    -- Content
    Title VARCHAR(300) NOT NULL,
    Content TEXT NOT NULL,
    ContentFormat ENUM('markdown', 'html', 'plain_text') DEFAULT 'markdown',
    
    -- Expertise validation
    AuthorCredentials TEXT, -- Self-reported credentials
    ExpertiseEvidence TEXT, -- Links to portfolio, LinkedIn, etc.
    CommunityEndorsements INTEGER DEFAULT 0,
    VerifiedExpert BOOLEAN DEFAULT FALSE,
    VerifiedBy VARCHAR(100) NULL,
    
    -- Usage and feedback
    ViewCount INTEGER DEFAULT 0,
    HelpfulVotes INTEGER DEFAULT 0,
    BookmarkCount INTEGER DEFAULT 0,
    ShareCount INTEGER DEFAULT 0,
    
    -- Content status
    ContentStatus ENUM('draft', 'published', 'featured', 'archived') DEFAULT 'draft',
    PublishedDate TIMESTAMP NULL,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (ExpertiseID),
    FOREIGN KEY (ExpertID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    FOREIGN KEY (VerifiedBy) REFERENCES Users(UserID) ON DELETE SET NULL,
    
    INDEX idx_expertise_expert (ExpertID),
    INDEX idx_expertise_book (BookID),
    INDEX idx_expertise_type (ExpertiseType),
    INDEX idx_expertise_status (ContentStatus),
    INDEX idx_expertise_helpful (HelpfulVotes),
    
    FULLTEXT INDEX ft_expertise_search (Title, Content, TopicKeywords)
);

-- Learning Paths Created by Community
CREATE TABLE LearningPaths (
    PathID INTEGER NOT NULL AUTO_INCREMENT,
    CreatorID VARCHAR(100) NOT NULL,
    PathTitle VARCHAR(300) NOT NULL,
    PathDescription TEXT,
    TargetAudience ENUM('beginner', 'intermediate', 'advanced', 'expert') NOT NULL,
    EstimatedDuration VARCHAR(100), -- "3 months", "1 year", etc.
    
    -- Path metadata
    CategoryPath VARCHAR(500),
    Tags JSON,
    Prerequisites TEXT,
    LearningObjectives TEXT,
    
    -- Community metrics
    FollowerCount INTEGER DEFAULT 0,
    CompletionCount INTEGER DEFAULT 0,
    AverageRating DECIMAL(3,2) DEFAULT 0.0,
    TotalRatings INTEGER DEFAULT 0,
    
    -- Path status
    PathStatus ENUM('draft', 'published', 'featured', 'archived') DEFAULT 'draft',
    IsOfficial BOOLEAN DEFAULT FALSE, -- Endorsed by platform
    
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (PathID),
    FOREIGN KEY (CreatorID) REFERENCES Users(UserID) ON DELETE CASCADE,
    
    INDEX idx_paths_creator (CreatorID),
    INDEX idx_paths_audience (TargetAudience),
    INDEX idx_paths_status (PathStatus),
    INDEX idx_paths_rating (AverageRating),
    
    FULLTEXT INDEX ft_paths_search (PathTitle, PathDescription, Tags)
);

-- Books in Learning Paths (Ordered Sequence)
CREATE TABLE LearningPathBooks (
    PathBookID INTEGER NOT NULL AUTO_INCREMENT,
    PathID INTEGER NOT NULL,
    BookID INTEGER NOT NULL,
    BookOrder INTEGER NOT NULL,
    
    -- Book's role in path
    BookRole ENUM('foundation', 'core', 'supplementary', 'advanced', 'reference') DEFAULT 'core',
    IsRequired BOOLEAN DEFAULT TRUE,
    EstimatedReadingTime VARCHAR(50), -- "2 weeks", "1 month"
    
    -- Guidance for learners
    ReadingNotes TEXT, -- What to focus on
    PrereadingPrep TEXT, -- What to review first
    PostreadingActivities TEXT, -- Exercises, projects
    
    -- Community feedback on this book's placement
    PlacementVotes INTEGER DEFAULT 0, -- Votes that this book belongs here
    PlacementComplaints INTEGER DEFAULT 0,
    
    AddedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (PathBookID),
    FOREIGN KEY (PathID) REFERENCES LearningPaths(PathID) ON DELETE CASCADE,
    FOREIGN KEY (BookID) REFERENCES Books(BookID) ON DELETE CASCADE,
    
    UNIQUE KEY UK_Path_Book_Order (PathID, BookOrder),
    INDEX idx_path_books_path (PathID),
    INDEX idx_path_books_book (BookID),
    INDEX idx_path_books_order (PathID, BookOrder)
);

-- =============================================
-- COMMUNITY REWARDS & INCENTIVES
-- =============================================

-- Contribution Rewards System
CREATE TABLE ContributionRewards (
    RewardID INTEGER NOT NULL AUTO_INCREMENT,
    ContributorID VARCHAR(100) NOT NULL,
    RewardType ENUM('points', 'badge', 'premium_time', 'cash', 'credit') NOT NULL,
    RewardValue DECIMAL(10,2) NOT NULL,
    RewardCurrency VARCHAR(10) DEFAULT 'points', -- 'points', 'USD', 'credits'
    
    -- Reason for reward
    RewardReason ENUM('book_contribution', 'metadata_improvement', 'expert_content', 'community_moderation', 'quality_review') NOT NULL,
    RelatedContributionID INTEGER NULL,
    RelatedContentID INTEGER NULL,
    
    -- Reward details
    RewardDescription TEXT,
    RewardStatus ENUM('pending', 'approved', 'paid', 'disputed') DEFAULT 'pending',
    ApprovedBy VARCHAR(100) NULL,
    
    EarnedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessedDate TIMESTAMP NULL,
    
    PRIMARY KEY (RewardID),
    FOREIGN KEY (ContributorID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (RelatedContributionID) REFERENCES BookContributions(ContributionID) ON DELETE SET NULL,
    FOREIGN KEY (ApprovedBy) REFERENCES Users(UserID) ON DELETE SET NULL,
    
    INDEX idx_rewards_contributor (ContributorID),
    INDEX idx_rewards_type (RewardType),
    INDEX idx_rewards_status (RewardStatus),
    INDEX idx_rewards_date (EarnedDate)
);

-- Community Badges & Achievements
CREATE TABLE CommunityBadges (
    BadgeID INTEGER NOT NULL AUTO_INCREMENT,
    BadgeName VARCHAR(100) NOT NULL,
    BadgeDescription TEXT,
    BadgeIcon VARCHAR(200), -- URL to badge image
    BadgeCategory ENUM('contribution', 'expertise', 'community', 'milestone', 'special') NOT NULL,
    
    -- Earning criteria
    RequirementDescription TEXT,
    RequiredPoints INTEGER DEFAULT 0,
    RequiredContributions INTEGER DEFAULT 0,
    RequiredRating DECIMAL(3,2) DEFAULT 0.0,
    IsActive BOOLEAN DEFAULT TRUE,
    
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (BadgeID),
    INDEX idx_badges_category (BadgeCategory),
    INDEX idx_badges_active (IsActive)
);

-- User Badge Achievements
CREATE TABLE UserBadges (
    UserBadgeID INTEGER NOT NULL AUTO_INCREMENT,
    UserID VARCHAR(100) NOT NULL,
    BadgeID INTEGER NOT NULL,
    EarnedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsDisplayed BOOLEAN DEFAULT TRUE, -- User choice to display on profile
    
    PRIMARY KEY (UserBadgeID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (BadgeID) REFERENCES CommunityBadges(BadgeID) ON DELETE CASCADE,
    
    UNIQUE KEY UK_User_Badge (UserID, BadgeID),
    INDEX idx_user_badges_user (UserID),
    INDEX idx_user_badges_badge (BadgeID)
);

-- =============================================
-- COLLABORATIVE QUALITY CONTROL
-- =============================================

-- Community Quality Assurance Teams
CREATE TABLE QualityAssuranceTeams (
    TeamID INTEGER NOT NULL AUTO_INCREMENT,
    TeamName VARCHAR(100) NOT NULL,
    TeamDescription TEXT,
    TeamLeaderID VARCHAR(100) NOT NULL,
    
    -- Team specialization
    SpecialtyCategories JSON, -- Categories this team focuses on
    QualityStandards TEXT, -- Team's quality criteria
    
    -- Team metrics
    MemberCount INTEGER DEFAULT 0,
    BooksReviewed INTEGER DEFAULT 0,
    AverageAccuracy DECIMAL(4,3) DEFAULT 0.0,
    
    -- Team status
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (TeamID),
    FOREIGN KEY (TeamLeaderID) REFERENCES Users(UserID) ON DELETE CASCADE,
    
    INDEX idx_qa_teams_leader (TeamLeaderID),
    INDEX idx_qa_teams_active (IsActive)
);

-- QA Team Memberships
CREATE TABLE QATeamMembers (
    MembershipID INTEGER NOT NULL AUTO_INCREMENT,
    TeamID INTEGER NOT NULL,
    UserID VARCHAR(100) NOT NULL,
    MemberRole ENUM('reviewer', 'specialist', 'coordinator', 'trainee') DEFAULT 'reviewer',
    
    JoinedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IsActive BOOLEAN DEFAULT TRUE,
    
    -- Performance metrics
    ReviewsCompleted INTEGER DEFAULT 0,
    AccuracyRating DECIMAL(4,3) DEFAULT 0.0,
    
    PRIMARY KEY (MembershipID),
    FOREIGN KEY (TeamID) REFERENCES QualityAssuranceTeams(TeamID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    
    UNIQUE KEY UK_Team_User (TeamID, UserID),
    INDEX idx_qa_members_team (TeamID),
    INDEX idx_qa_members_user (UserID)
);

-- =============================================
-- STORED PROCEDURES FOR COMMUNITY FEATURES
-- =============================================

DELIMITER //

-- Process Book Contribution
CREATE PROCEDURE ProcessBookContribution(
    IN p_ContributionID INTEGER,
    IN p_ReviewerID VARCHAR(100),
    IN p_Decision ENUM('approved', 'rejected', 'needs_revision'),
    IN p_ReviewNotes TEXT
)
BEGIN
    DECLARE v_contributor_id VARCHAR(100);
    DECLARE v_contribution_type ENUM('new_book', 'improved_metadata', 'cover_image', 'table_of_contents', 'book_description', 'category_suggestion');
    DECLARE v_reward_points INTEGER DEFAULT 0;
    
    -- Get contribution details
    SELECT ContributorID, ContributionType INTO v_contributor_id, v_contribution_type
    FROM BookContributions 
    WHERE ContributionID = p_ContributionID;
    
    -- Update contribution status
    UPDATE BookContributions 
    SET ContributionStatus = p_Decision,
        ReviewedBy = p_ReviewerID,
        ReviewNotes = p_ReviewNotes,
        ReviewedDate = NOW(),
        ApprovedDate = CASE WHEN p_Decision = 'approved' THEN NOW() ELSE NULL END
    WHERE ContributionID = p_ContributionID;
    
    -- Award points for approved contributions
    IF p_Decision = 'approved' THEN
        SET v_reward_points = CASE v_contribution_type
            WHEN 'new_book' THEN 100
            WHEN 'improved_metadata' THEN 25
            WHEN 'cover_image' THEN 15
            WHEN 'table_of_contents' THEN 20
            WHEN 'book_description' THEN 30
            WHEN 'category_suggestion' THEN 10
            ELSE 5
        END;
        
        -- Add reward
        INSERT INTO ContributionRewards (
            ContributorID, RewardType, RewardValue, RewardReason,
            RelatedContributionID, RewardDescription, RewardStatus
        ) VALUES (
            v_contributor_id, 'points', v_reward_points, 'book_contribution',
            p_ContributionID, CONCAT('Approved ', v_contribution_type), 'approved'
        );
        
        -- Update user's total contribution count
        UPDATE Users 
        SET ReputationScore = ReputationScore + v_reward_points,
            TotalRequestsFulfilled = TotalRequestsFulfilled + 1
        WHERE UserID = v_contributor_id;
    END IF;
    
END //

-- Calculate Community Quality Score
CREATE PROCEDURE CalculateCommunityQualityScore(IN p_BookID INTEGER)
BEGIN
    DECLARE community_rating DECIMAL(3,2) DEFAULT 0.0;
    DECLARE contribution_score DECIMAL(3,2) DEFAULT 0.0;
    DECLARE expert_score DECIMAL(3,2) DEFAULT 0.0;
    DECLARE final_score DECIMAL(3,2) DEFAULT 0.0;
    
    -- Get community rating (weighted by user reputation)
    SELECT AVG(br.StarRating * (1 + (u.ReputationScore / 1000))) INTO community_rating
    FROM BookRatings br
    JOIN Users u ON br.UserID = u.UserID
    WHERE br.BookID = p_BookID AND br.IsModerated = FALSE;
    
    -- Get contribution quality score
    SELECT AVG(cv.QualityRating) INTO contribution_score
    FROM BookContributions bc
    JOIN ContributionValidation cv ON bc.ContributionID = cv.ContributionID
    WHERE bc.BookID = p_BookID AND cv.ValidationResult = 'approved';
    
    -- Get expert content score
    SELECT AVG((ec.HelpfulVotes + 1) / (ec.ViewCount + 1)) INTO expert_score
    FROM ExpertContributions ec
    WHERE ec.BookID = p_BookID AND ec.ContentStatus = 'published';
    
    -- Calculate weighted final score
    SET final_score = (
        COALESCE(community_rating, 0) * 0.5 +
        COALESCE(contribution_score, 0) * 0.3 +
        COALESCE(expert_score, 0) * 0.2
    );
    
    -- Update book's community quality score
    UPDATE Books 
    SET QualityScore = final_score
    WHERE BookID = p_BookID;
    
END //

DELIMITER ;

-- =============================================
-- SAMPLE COMMUNITY DATA
-- =============================================

-- Sample community badges
INSERT INTO CommunityBadges (BadgeName, BadgeDescription, BadgeCategory, RequiredContributions) VALUES
('First Contributor', 'Made your first book contribution', 'contribution', 1),
('Metadata Master', 'Improved metadata for 50+ books', 'contribution', 50),
('Expert Curator', 'Created 10+ expert content pieces', 'expertise', 10),
('Community Champion', 'Helped moderate and improve community', 'community', 0),
('Library Builder', 'Contributed 100+ books to the collection', 'milestone', 100);

-- Sample quality assurance team
INSERT INTO QualityAssuranceTeams (TeamName, TeamDescription, TeamLeaderID, SpecialtyCategories) VALUES
('Programming Books QA', 'Ensures quality of programming and computer science books', 'user001', '["Programming", "Computer Science", "Software Engineering"]'),
('Science & Math QA', 'Reviews scientific and mathematical content for accuracy', 'user003', '["Mathematics", "Physics", "Chemistry", "Biology"]');

/*
COMMUNITY PLATFORM TRANSFORMATION:

This transforms your library into a **living, breathing knowledge ecosystem** where:

1. **Members Contribute Content**:
   - Upload books to fill gaps in collection
   - Improve metadata and descriptions
   - Add covers, TOCs, and supplementary materials
   - Create learning paths and study guides

2. **Collaborative Quality Control**:
   - Community validates all contributions
   - Expert reviewers ensure accuracy
   - Reputation-weighted quality scores
   - Specialized QA teams for different subjects

3. **Knowledge Sharing Network**:
   - Expert contributions (summaries, guides)
   - Learning paths created by community
   - Discussion threads on improvements
   - Peer-to-peer knowledge transfer

4. **Reward & Recognition System**:
   - Points and badges for contributions
   - Premium access for contributors
   - Cash rewards for high-value additions
   - Expert status and verification

5. **Network Effects**:
   - More members = more content
   - Better quality through collective intelligence
   - Self-sustaining growth
   - Community ownership and engagement

BUSINESS MODEL TRANSFORMATION:
- Revenue sharing with contributors
- Premium memberships for heavy contributors
- Corporate partnerships for expert content
- Data licensing for educational analytics
- Community marketplace for expertise

This could become the **"Stack Overflow for Books"** - a massive, community-driven knowledge platform!
*/