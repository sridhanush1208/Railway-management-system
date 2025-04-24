-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Apr 24, 2025 at 11:39 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `rail_db`
--

DELIMITER $$
--
-- Procedures
--
DROP PROCEDURE IF EXISTS `book_ticket`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `book_ticket` (IN `p_userid` INT, IN `p_trainid` INT, IN `p_class` VARCHAR(20), IN `p_from_station` VARCHAR(50), IN `p_to_station` VARCHAR(50), IN `p_passenger_name` VARCHAR(100), IN `p_email` VARCHAR(100), IN `p_concession` VARCHAR(50))   BEGIN
    DECLARE seat_available INT DEFAULT 0;
    DECLARE base_fare DECIMAL(10,2) DEFAULT 0;
    DECLARE journey_factor DECIMAL(10,2) DEFAULT 1;
    DECLARE discount_rate DECIMAL(4,2) DEFAULT 0;
    DECLARE final_amount DECIMAL(10,2);
    DECLARE pnr_val VARCHAR(40);

    DECLARE rac_count INT DEFAULT 0;
    DECLARE wl_count INT DEFAULT 0;
    DECLARE waiting_list_no INT DEFAULT 0;  

    -- Variables for confirmed seat assignment.
    DECLARE capacity INT DEFAULT 0;
    DECLARE new_available INT DEFAULT 0;
    DECLARE seat_assigned INT DEFAULT 0;
    DECLARE coach_assigned VARCHAR(10);

    -- Variable for RAC assignment.
    DECLARE rac_no INT DEFAULT 0;

    -- Maximum allowed RAC passengers per class.
    DECLARE max_rac INT DEFAULT 0;
    
    -- Determine maximum RAC capacity based on class.
    IF p_class = 'firstclass' THEN
        SET max_rac = 6;
    ELSEIF p_class = '2ac' THEN
        SET max_rac = 10;
    ELSEIF p_class = '3ac' THEN
        SET max_rac = 14;
    ELSEIF p_class = 'sleeper' THEN
        SET max_rac = 20;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid class provided';
    END IF;

    -- Generate unique PNR.
    SET pnr_val = CONCAT('PNR', p_trainid, UNIX_TIMESTAMP(), FLOOR(RAND()*1000));

    -- Determine base fare per class.
    IF p_class = 'sleeper' THEN
        SET base_fare = 100;
    ELSEIF p_class = '3ac' THEN
        SET base_fare = 200;
    ELSEIF p_class = '2ac' THEN
        SET base_fare = 300;
    ELSEIF p_class = 'firstclass' THEN
        SET base_fare = 400;
    END IF;

    -- Calculate amount and apply concession discount.
    SET final_amount = base_fare * journey_factor;
    IF p_concession = 'student' THEN
        SET discount_rate = 0.20;
    ELSEIF p_concession = 'senior citizen' THEN
        SET discount_rate = 0.40;
    ELSEIF p_concession = 'disabled' THEN
        SET discount_rate = 0.60;
    ELSE
        SET discount_rate = 0;
    END IF;
    SET final_amount = final_amount * (1 - discount_rate);

    -- Check confirmed seat availability.
    IF p_class = 'sleeper' THEN
        SELECT available_sleeper INTO seat_available FROM seats WHERE trainid = p_trainid;
    ELSEIF p_class = '3ac' THEN
        SELECT available_3ac INTO seat_available FROM seats WHERE trainid = p_trainid;
    ELSEIF p_class = '2ac' THEN
        SELECT available_2ac INTO seat_available FROM seats WHERE trainid = p_trainid;
    ELSEIF p_class = 'firstclass' THEN
        SELECT available_firstclass INTO seat_available FROM seats WHERE trainid = p_trainid;
    END IF;

    IF seat_available IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seat availability not found for given train/class';
    END IF;

    START TRANSACTION;
    
    IF seat_available > 0 THEN
        -- Confirmed booking: update seat availability.
        IF p_class = 'sleeper' THEN
            UPDATE seats SET available_sleeper = available_sleeper - 1 WHERE trainid = p_trainid;
            SELECT available_sleeper INTO new_available FROM seats WHERE trainid = p_trainid;
            SELECT max_sleeper INTO capacity FROM trains WHERE trainid = p_trainid;
        ELSEIF p_class = '3ac' THEN
            UPDATE seats SET available_3ac = available_3ac - 1 WHERE trainid = p_trainid;
            SELECT available_3ac INTO new_available FROM seats WHERE trainid = p_trainid;
            SELECT max_3ac INTO capacity FROM trains WHERE trainid = p_trainid;
        ELSEIF p_class = '2ac' THEN
            UPDATE seats SET available_2ac = available_2ac - 1 WHERE trainid = p_trainid;
            SELECT available_2ac INTO new_available FROM seats WHERE trainid = p_trainid;
            SELECT max_2ac INTO capacity FROM trains WHERE trainid = p_trainid;
        ELSEIF p_class = 'firstclass' THEN
            UPDATE seats SET available_firstclass = available_firstclass - 1 WHERE trainid = p_trainid;
            SELECT available_firstclass INTO new_available FROM seats WHERE trainid = p_trainid;
            SELECT max_firstclass INTO capacity FROM trains WHERE trainid = p_trainid;
        END IF;

        IF capacity IS NULL OR new_available IS NULL THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Could not retrieve seat capacity or availability';
        END IF;

        -- Compute confirmed seat assignment.
        SET seat_assigned = capacity - new_available;
        IF seat_assigned <= 50 THEN
            SET coach_assigned = 'A';
        ELSEIF seat_assigned <= 100 THEN
            SET coach_assigned = 'B';
        ELSEIF seat_assigned <= 150 THEN
            SET coach_assigned = 'C';
        ELSE
            SET coach_assigned = 'D';
        END IF;

        INSERT INTO tickets (pnr, userid, trainid, class, from_station, to_station, status, amount, seat_no, coach_no)
        VALUES (pnr_val, p_userid, p_trainid, p_class, p_from_station, p_to_station, 'confirmed', final_amount, seat_assigned, coach_assigned);

        INSERT INTO payment (pnr, userid, trainid, amount, payment_status)
        VALUES (pnr_val, p_userid, p_trainid, final_amount, 'Paid');
    ELSE
        -- No confirmed seat available: RAC or WL.
        SELECT COUNT(*) INTO rac_count FROM rac WHERE trainid = p_trainid AND class = p_class;
        IF rac_count < max_rac THEN
            SET rac_no = FLOOR(rac_count / 2) + 1;
            INSERT INTO rac (pnr, userid, trainid, class, from_station, to_station, status, amount, rac_no)
            VALUES (pnr_val, p_userid, p_trainid, p_class, p_from_station, p_to_station, 'active', final_amount, rac_no);
        ELSE
            SELECT COUNT(*) INTO wl_count FROM waiting_list WHERE trainid = p_trainid AND class = p_class;
            SET waiting_list_no = wl_count + 1;
            INSERT INTO waiting_list (pnr, userid, trainid, class, from_station, to_station, status, amount, waiting_list_no)
            VALUES (pnr_val, p_userid, p_trainid, p_class, p_from_station, p_to_station, 'active', final_amount, waiting_list_no);
        END IF;
    END IF;

    -- Insert passenger record.
    INSERT INTO passengers (name, pnr, email, concession_type, trainid)
    VALUES (p_passenger_name, pnr_val, p_email, p_concession, p_trainid);

    COMMIT;

    SELECT pnr_val AS BookingPNR, final_amount AS Amount;
END$$

DROP PROCEDURE IF EXISTS `cancel_ticket`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `cancel_ticket` (IN `p_pnr` VARCHAR(30))   BEGIN
    DECLARE booked_trainid INT;
    DECLARE booked_class VARCHAR(20);
    DECLARE booked_amount DECIMAL(10,2);
    DECLARE booked_userid INT;
    
    DECLARE rac_pnr VARCHAR(30);
    DECLARE rac_userid INT;
    DECLARE rac_amount DECIMAL(10,2);
    DECLARE rac_class VARCHAR(20);
    DECLARE rac_from VARCHAR(50);
    DECLARE rac_to VARCHAR(50);
    DECLARE rac_no INT;
    
    DECLARE wl_pnr VARCHAR(30);
    DECLARE wl_userid INT;
    DECLARE wl_amount DECIMAL(10,2);
    DECLARE wl_class VARCHAR(20);
    DECLARE wl_from VARCHAR(50);
    DECLARE wl_to VARCHAR(50);
    DECLARE waiting_list_no INT;
    
    DECLARE new_available INT DEFAULT 0;
    DECLARE capacity INT DEFAULT 0;
    DECLARE seat_assigned INT DEFAULT 0;
    DECLARE coach_assigned VARCHAR(10);
    
    DECLARE rac_count INT DEFAULT 0;
    
    START TRANSACTION;
    
    -- 1) Confirmed ticket cancellation
    IF EXISTS (SELECT 1 FROM tickets WHERE pnr = p_pnr) THEN
        SELECT trainid, class, amount, userid
          INTO booked_trainid, booked_class, booked_amount, booked_userid
          FROM tickets WHERE pnr = p_pnr;
        
        DELETE FROM tickets WHERE pnr = p_pnr;
        
        -- Restore seat availability
        IF booked_class = 'sleeper' THEN
            UPDATE seats SET available_sleeper = available_sleeper + 1 WHERE trainid = booked_trainid;
        ELSEIF booked_class = '3ac' THEN
            UPDATE seats SET available_3ac = available_3ac + 1 WHERE trainid = booked_trainid;
        ELSEIF booked_class = '2ac' THEN
            UPDATE seats SET available_2ac = available_2ac + 1 WHERE trainid = booked_trainid;
        ELSEIF booked_class = 'firstclass' THEN
            UPDATE seats SET available_firstclass = available_firstclass + 1 WHERE trainid = booked_trainid;
        END IF;
        
        -- Refund 80%
        INSERT INTO refund (pnr, userid, trainid, refund_amount)
        VALUES (p_pnr, booked_userid, booked_trainid, booked_amount * 0.8);
        
        -- Promote earliest RAC to confirmed...
        IF EXISTS (
            SELECT 1
              FROM rac
             WHERE trainid = booked_trainid
               AND class   = booked_class
             ORDER BY pnr
             LIMIT 1
        ) THEN
            SELECT pnr, userid, amount, class, from_station, to_station, rac_no
              INTO rac_pnr, rac_userid, rac_amount, rac_class, rac_from, rac_to, rac_no
              FROM rac
             WHERE trainid = booked_trainid
               AND class   = booked_class
             ORDER BY pnr
             LIMIT 1;
            
            DELETE FROM rac WHERE pnr = rac_pnr;
            
            -- Allocate seat to RAC passenger
            IF booked_class = 'sleeper' THEN
                UPDATE seats SET available_sleeper = available_sleeper - 1 WHERE trainid = booked_trainid;
                SELECT available_sleeper INTO new_available FROM seats WHERE trainid = booked_trainid;
                SELECT max_sleeper     INTO capacity      FROM trains WHERE trainid = booked_trainid;
            ELSEIF booked_class = '3ac' THEN
                UPDATE seats SET available_3ac = available_3ac - 1 WHERE trainid = booked_trainid;
                SELECT available_3ac     INTO new_available FROM seats WHERE trainid = booked_trainid;
                SELECT max_3ac         INTO capacity      FROM trains WHERE trainid = booked_trainid;
            ELSEIF booked_class = '2ac' THEN
                UPDATE seats SET available_2ac = available_2ac - 1 WHERE trainid = booked_trainid;
                SELECT available_2ac     INTO new_available FROM seats WHERE trainid = booked_trainid;
                SELECT max_2ac         INTO capacity      FROM trains WHERE trainid = booked_trainid;
            ELSE
                UPDATE seats SET available_firstclass = available_firstclass - 1 WHERE trainid = booked_trainid;
                SELECT available_firstclass INTO new_available FROM seats WHERE trainid = booked_trainid;
                SELECT max_firstclass     INTO capacity      FROM trains WHERE trainid = booked_trainid;
            END IF;
            
            SET seat_assigned = capacity - new_available;
            IF seat_assigned <= 50 THEN
                SET coach_assigned = 'A';
            ELSEIF seat_assigned <= 100 THEN
                SET coach_assigned = 'B';
            ELSEIF seat_assigned <= 150 THEN
                SET coach_assigned = 'C';
            ELSE
                SET coach_assigned = 'D';
            END IF;
            
            INSERT INTO tickets (pnr, userid, trainid, class, from_station, to_station, status, amount, seat_no, coach_no)
            VALUES (rac_pnr, rac_userid, booked_trainid, rac_class, rac_from, rac_to, 'confirmed', rac_amount, seat_assigned, coach_assigned);
            
            INSERT INTO payment (pnr, userid, trainid, amount, payment_status)
            VALUES (rac_pnr, rac_userid, booked_trainid, rac_amount, 'Paid');
            
            -- Then promote WL → RAC if capacity allows
            SELECT COUNT(*) INTO rac_count
              FROM rac
             WHERE trainid = booked_trainid
               AND class   = booked_class;
            
            IF EXISTS (
                SELECT 1
                  FROM waiting_list
                 WHERE trainid = booked_trainid
                   AND class   = booked_class
                 ORDER BY pnr
                 LIMIT 1
            )
            AND rac_count < (
                CASE booked_class
                    WHEN 'firstclass' THEN 6
                    WHEN '2ac'        THEN 10
                    WHEN '3ac'        THEN 14
                    WHEN 'sleeper'    THEN 20
                    ELSE 0
                END
            ) THEN
                SELECT pnr, userid, amount, class, from_station, to_station
                  INTO wl_pnr, wl_userid, wl_amount, wl_class, wl_from, wl_to
                  FROM waiting_list
                 WHERE trainid = booked_trainid
                   AND class   = booked_class
                 ORDER BY pnr
                 LIMIT 1;
                
                DELETE FROM waiting_list WHERE pnr = wl_pnr;
                
                SET rac_no = FLOOR(rac_count / 2) + 1;
                INSERT INTO rac (pnr, userid, trainid, class, from_station, to_station, status, amount, rac_no)
                VALUES (wl_pnr, wl_userid, booked_trainid, wl_class, wl_from, wl_to, 'active', wl_amount, rac_no);
            END IF;
        END IF;

    -- 2) RAC cancellation branch
    ELSEIF EXISTS (SELECT 1 FROM rac WHERE pnr = p_pnr) THEN
        SELECT trainid, amount, userid, class
          INTO booked_trainid, booked_amount, booked_userid, booked_class
          FROM rac WHERE pnr = p_pnr;
        
        DELETE FROM rac WHERE pnr = p_pnr;
        
        -- Refund 80%
        INSERT INTO refund (pnr, userid, trainid, refund_amount)
        VALUES (p_pnr, booked_userid, booked_trainid, booked_amount * 0.8);
        
        -- Promote WL → RAC if any
        IF EXISTS (
            SELECT 1
              FROM waiting_list
             WHERE trainid = booked_trainid
               AND class   = booked_class
             ORDER BY pnr
             LIMIT 1
        ) THEN
            SELECT pnr, userid, amount, class, from_station, to_station
              INTO wl_pnr, wl_userid, wl_amount, wl_class, wl_from, wl_to
              FROM waiting_list
             WHERE trainid = booked_trainid
               AND class   = booked_class
             ORDER BY pnr
             LIMIT 1;
            
            DELETE FROM waiting_list WHERE pnr = wl_pnr;
            
            SELECT COUNT(*) INTO rac_count
              FROM rac
             WHERE trainid = booked_trainid
               AND class   = booked_class;
            SET rac_no = FLOOR(rac_count / 2) + 1;
            INSERT INTO rac (pnr, userid, trainid, class, from_station, to_station, status, amount, rac_no)
            VALUES (wl_pnr, wl_userid, booked_trainid, wl_class, wl_from, wl_to, 'active', wl_amount, rac_no);
        END IF;

    -- 3) Waiting-list cancellation
    ELSEIF EXISTS (SELECT 1 FROM waiting_list WHERE pnr = p_pnr) THEN
        SELECT trainid, amount, userid, class
          INTO booked_trainid, booked_amount, booked_userid, booked_class
          FROM waiting_list WHERE pnr = p_pnr;
        
        DELETE FROM waiting_list WHERE pnr = p_pnr;
        
        -- Refund 80%
        INSERT INTO refund (pnr, userid, trainid, refund_amount)
        VALUES (p_pnr, booked_userid, booked_trainid, booked_amount * 0.8);

    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PNR not found in any booking category';
    END IF;
    
    -- Remove passenger record
    DELETE FROM passengers WHERE pnr = p_pnr;
    
    COMMIT;
    
    SELECT 'Cancellation successful' AS Result;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `passengers`
--

DROP TABLE IF EXISTS `passengers`;
CREATE TABLE `passengers` (
  `passenger_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `pnr` varchar(30) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `concession_type` enum('student','senior citizen','disabled','none') DEFAULT 'none',
  `trainid` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `passengers`
--

INSERT INTO `passengers` (`passenger_id`, `name`, `pnr`, `email`, `concession_type`, `trainid`) VALUES
(1, 'Guna', 'PNR11745421477182', 'Guna@example.com', 'student', 1),
(2, 'Guna', 'PNR11745421538685', 'Guna@example.com', 'none', 1),
(3, 'Guna', 'PNR11745421552577', 'Guna@example.com', 'none', 1),
(4, 'Dhanush', 'PNR11745421690527', 'Dhanush@example.com', 'none', 1),
(5, 'vineel', 'PNR11745421690352', 'vineel@example.com', 'senior citizen', 1),
(6, 'guna', 'PNR11745421690181', 'guna@example.com', 'disabled', 1),
(7, 'Dhanush', 'PNR11745421707919', 'Dhanush@example.com', 'none', 1),
(8, 'vineel', 'PNR11745421707707', 'vineel@example.com', 'senior citizen', 1),
(9, 'guna', 'PNR11745421708777', 'guna@example.com', 'disabled', 1),
(10, 'Dhanush', 'PNR11745421716679', 'Dhanush@example.com', 'none', 1),
(11, 'vineel', 'PNR11745421716285', 'vineel@example.com', 'senior citizen', 1),
(12, 'guna', 'PNR11745421716391', 'guna@example.com', 'disabled', 1),
(13, 'Dhanush', 'PNR11745421805218', 'Dhanush@example.com', 'none', 1),
(14, 'vineel', 'PNR1174542180556', 'vineel@example.com', 'senior citizen', 1),
(15, 'guna', 'PNR11745421805624', 'guna@example.com', 'disabled', 1),
(16, 'Dhanush', 'PNR11745421812953', 'Dhanush@example.com', 'none', 1),
(17, 'vineel', 'PNR11745421812285', 'vineel@example.com', 'senior citizen', 1),
(18, 'guna', 'PNR11745421812566', 'guna@example.com', 'disabled', 1),
(19, 'Dhanush', 'PNR11745421821628', 'Dhanush@example.com', 'none', 1),
(21, 'guna', 'PNR11745421821493', 'guna@example.com', 'disabled', 1),
(22, 'Dhanush', 'PNR11745421829267', 'Dhanush@example.com', 'none', 1),
(23, 'vineel', 'PNR11745421830191', 'vineel@example.com', 'senior citizen', 1),
(24, 'guna', 'PNR11745421830155', 'guna@example.com', 'disabled', 1),
(25, 'Dhanush', 'PNR11745421849661', 'Dhanush@example.com', 'none', 1),
(26, 'vineel', 'PNR11745421849765', 'vineel@example.com', 'senior citizen', 1),
(27, 'guna', 'PNR11745421849846', 'guna@example.com', 'disabled', 1),
(28, 'Dhanush', 'PNR11745421887643', 'Dhanush@example.com', 'disabled', 1),
(29, 'vineel', 'PNR11745421887935', 'vineel@example.com', 'student', 1),
(30, 'guna', 'PNR11745421887749', 'guna@example.com', 'none', 1),
(31, 'Dhanush', 'PNR11745421894629', 'Dhanush@example.com', 'disabled', 1),
(32, 'vineel', 'PNR11745421894550', 'vineel@example.com', 'student', 1),
(33, 'guna', 'PNR11745421894860', 'guna@example.com', 'none', 1),
(34, 'Dhanush', 'PNR11745421901377', 'Dhanush@example.com', 'disabled', 1),
(35, 'vineel', 'PNR1174542190174', 'vineel@example.com', 'student', 1),
(36, 'guna', 'PNR11745421901240', 'guna@example.com', 'none', 1),
(37, 'Dhanush', 'PNR11745421908181', 'Dhanush@example.com', 'disabled', 1),
(38, 'vineel', 'PNR11745421908168', 'vineel@example.com', 'student', 1),
(39, 'guna', 'PNR11745421908298', 'guna@example.com', 'none', 1),
(40, 'Dhanush', 'PNR11745421917539', 'Dhanush@example.com', 'disabled', 1),
(41, 'vineel', 'PNR11745421917150', 'vineel@example.com', 'student', 1),
(42, 'guna', 'PNR11745421917132', 'guna@example.com', 'none', 1),
(43, 'Dhanush', 'PNR11745421985312', 'Dhanush@example.com', 'disabled', 1),
(44, 'vineel', 'PNR11745421986904', 'vineel@example.com', 'student', 1),
(45, 'guna', 'PNR11745421986584', 'guna@example.com', 'none', 1),
(46, 'Dhanush', 'PNR11745421993297', 'Dhanush@example.com', 'disabled', 1),
(47, 'vineel', 'PNR11745421993981', 'vineel@example.com', 'student', 1),
(48, 'guna', 'PNR1174542199313', 'guna@example.com', 'none', 1),
(49, 'Dhanush', 'PNR11745422167166', 'Dhanush@example.com', 'disabled', 1),
(50, 'vineel', 'PNR11745422167615', 'vineel@example.com', 'student', 1),
(51, 'guna', 'PNR11745422168576', 'guna@example.com', 'none', 1),
(56, 'Gunavardhan', 'PNR61745529539493', 'hello12@gmail.com', 'student', 6),
(57, 'qwDSFDG', 'PNR11745529997203', 'jiangly@gmail.com', 'student', 1),
(58, 'sanjay', 'PNR51745530210637', 'hello12@gmail.com', 'senior citizen', 5);

-- --------------------------------------------------------

--
-- Table structure for table `payment`
--

DROP TABLE IF EXISTS `payment`;
CREATE TABLE `payment` (
  `payment_id` int(11) NOT NULL,
  `pnr` varchar(30) NOT NULL,
  `userid` int(11) NOT NULL,
  `trainid` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `payment_status` enum('Paid','Refunded') DEFAULT 'Paid',
  `payment_date` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payment`
--

INSERT INTO `payment` (`payment_id`, `pnr`, `userid`, `trainid`, `amount`, `payment_status`, `payment_date`) VALUES
(1, 'PNR11745421477182', 1, 1, 320.00, 'Paid', '2025-04-23 15:17:57'),
(2, 'PNR11745421538685', 1, 1, 400.00, 'Paid', '2025-04-23 15:18:58'),
(3, 'PNR11745421552577', 1, 1, 400.00, 'Paid', '2025-04-23 15:19:12'),
(4, 'PNR11745421690527', 1, 1, 400.00, 'Paid', '2025-04-23 15:21:30'),
(5, 'PNR11745421690352', 2, 1, 240.00, 'Paid', '2025-04-23 15:21:30'),
(6, 'PNR11745421690181', 3, 1, 160.00, 'Paid', '2025-04-23 15:21:30'),
(7, 'PNR11745421707919', 1, 1, 400.00, 'Paid', '2025-04-23 15:21:47'),
(8, 'PNR11745421707707', 2, 1, 240.00, 'Paid', '2025-04-23 15:21:47'),
(9, 'PNR11745421708777', 3, 1, 160.00, 'Paid', '2025-04-23 15:21:48'),
(10, 'PNR11745421716679', 1, 1, 400.00, 'Paid', '2025-04-23 15:21:56'),
(11, 'PNR11745421716285', 2, 1, 240.00, 'Paid', '2025-04-23 15:21:56'),
(12, 'PNR11745421716391', 3, 1, 160.00, 'Paid', '2025-04-23 15:21:56'),
(13, 'PNR11745421805218', 1, 1, 400.00, 'Paid', '2025-04-23 15:23:25'),
(14, 'PNR1174542180556', 2, 1, 240.00, 'Paid', '2025-04-23 15:23:25'),
(15, 'PNR11745421805624', 3, 1, 160.00, 'Paid', '2025-04-23 15:23:25'),
(16, 'PNR11745421812953', 1, 1, 400.00, 'Paid', '2025-04-23 15:23:32'),
(17, 'PNR11745421812285', 2, 1, 240.00, 'Paid', '2025-04-23 15:23:32'),
(18, 'PNR11745421812566', 3, 1, 160.00, 'Paid', '2025-04-23 15:23:32'),
(19, 'PNR11745421821628', 1, 1, 400.00, 'Paid', '2025-04-23 15:23:41'),
(20, 'PNR11745421821275', 2, 1, 240.00, 'Paid', '2025-04-23 15:23:41'),
(21, 'PNR11745421821493', 3, 1, 160.00, 'Paid', '2025-04-23 15:42:39'),
(22, 'PNR11745429781744', 4, 1, 240.00, 'Paid', '2025-04-23 17:36:21'),
(23, 'PNR61745430911923', 4, 6, 60.00, 'Paid', '2025-04-23 17:55:11'),
(24, 'PNR51745528372533', 4, 5, 320.00, 'Paid', '2025-04-24 20:59:32'),
(25, 'PNR61745529539493', 4, 6, 160.00, 'Paid', '2025-04-24 21:18:59'),
(26, 'PNR11745529997203', 5, 1, 240.00, 'Paid', '2025-04-24 21:26:37'),
(27, 'PNR51745530210637', 4, 5, 120.00, 'Paid', '2025-04-24 21:30:10');

-- --------------------------------------------------------

--
-- Table structure for table `rac`
--

DROP TABLE IF EXISTS `rac`;
CREATE TABLE `rac` (
  `pnr` varchar(30) NOT NULL,
  `userid` int(11) NOT NULL,
  `trainid` int(11) NOT NULL,
  `class` enum('sleeper','3ac','2ac','firstclass') NOT NULL,
  `from_station` varchar(50) DEFAULT NULL,
  `to_station` varchar(50) DEFAULT NULL,
  `status` enum('active','cancelled') DEFAULT 'active',
  `amount` decimal(10,2) NOT NULL,
  `rac_no` int(11) DEFAULT NULL COMMENT 'RAC seat number (2 persons per RAC)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rac`
--

INSERT INTO `rac` (`pnr`, `userid`, `trainid`, `class`, `from_station`, `to_station`, `status`, `amount`, `rac_no`) VALUES
('PNR11745421829267', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 1),
('PNR11745421830155', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 2),
('PNR11745421830191', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 240.00, 2),
('PNR11745421849661', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 3),
('PNR11745421849765', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 240.00, 3),
('PNR11745421849846', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 3);

-- --------------------------------------------------------

--
-- Table structure for table `refund`
--

DROP TABLE IF EXISTS `refund`;
CREATE TABLE `refund` (
  `pnr` varchar(30) NOT NULL,
  `userid` int(11) NOT NULL,
  `trainid` int(11) NOT NULL,
  `refund_amount` decimal(10,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `refund`
--

INSERT INTO `refund` (`pnr`, `userid`, `trainid`, `refund_amount`, `created_at`) VALUES
('PNR11745421821275', 2, 1, 192.00, '2025-04-23 15:42:39'),
('PNR11745429781744', 4, 1, 192.00, '2025-04-24 21:02:51'),
('PNR11745430032342', 4, 1, 128.00, '2025-04-23 17:55:49'),
('PNR51745528372533', 4, 5, 256.00, '2025-04-24 21:19:46'),
('PNR61745430911923', 4, 6, 48.00, '2025-04-24 21:30:48');

-- --------------------------------------------------------

--
-- Table structure for table `routes`
--

DROP TABLE IF EXISTS `routes`;
CREATE TABLE `routes` (
  `routeid` int(11) NOT NULL,
  `trainid` int(11) NOT NULL,
  `route_name` varchar(100) DEFAULT NULL COMMENT 'Descriptive name (optional)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `routes`
--

INSERT INTO `routes` (`routeid`, `trainid`, `route_name`) VALUES
(1, 1, 'Rajdhani Express'),
(2, 2, 'Shatabdi Express'),
(3, 3, 'Duronto Express'),
(4, 4, 'Garib Rath Express'),
(5, 5, 'Tejas Express'),
(6, 6, 'Humsafar Express'),
(7, 7, 'Double Decker Express'),
(8, 8, 'Vande Bharat Express'),
(9, 9, 'Mahamana Express'),
(10, 10, 'Flying Ranee'),
(11, 11, 'Deccan Queen'),
(12, 12, 'Mangala Lakshadweep Express'),
(13, 13, 'Kerala Express'),
(14, 14, 'Grand Trunk Express'),
(15, 15, 'Tamil Nadu Express'),
(16, 16, 'Andaman Express'),
(17, 17, 'Amritsar Express'),
(18, 18, 'Goa Express'),
(19, 19, 'Kanchenjunga Express'),
(20, 20, 'Darjeeling Mail'),
(21, 21, 'Palace on Wheels'),
(22, 22, 'Kalka Mail'),
(23, 23, 'Chennai Mail'),
(24, 24, 'Janshatabdi Express'),
(25, 25, 'Antyodaya Express');

-- --------------------------------------------------------

--
-- Table structure for table `route_stops`
--

DROP TABLE IF EXISTS `route_stops`;
CREATE TABLE `route_stops` (
  `stopid` int(11) NOT NULL,
  `routeid` int(11) NOT NULL,
  `station_name` varchar(50) NOT NULL,
  `stop_order` int(11) NOT NULL COMMENT '1 = first, 2 = second, ...',
  `arrival_time` time NOT NULL,
  `departure_time` time DEFAULT NULL COMMENT 'NULL if same as arrival or for terminus'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `route_stops`
--

INSERT INTO `route_stops` (`stopid`, `routeid`, `station_name`, `stop_order`, `arrival_time`, `departure_time`) VALUES
(1, 1, 'New Delhi', 1, '06:00:00', '06:05:00'),
(2, 1, 'Kanpur Central', 2, '12:00:00', '12:05:00'),
(3, 1, 'Patna Junction', 3, '18:00:00', '18:05:00'),
(4, 1, 'Howrah', 4, '23:00:00', NULL),
(5, 2, 'New Delhi', 1, '06:00:00', '06:05:00'),
(6, 2, 'Panipat Junction', 2, '12:00:00', '12:05:00'),
(7, 2, 'Ambala Cantt', 3, '18:00:00', '18:05:00'),
(8, 2, 'Chandigarh', 4, '23:00:00', NULL),
(9, 3, 'New Delhi', 1, '06:00:00', '06:05:00'),
(10, 3, 'Prayagraj Junction', 2, '12:00:00', '12:05:00'),
(11, 3, 'Varanasi Junction', 3, '18:00:00', '18:05:00'),
(12, 3, 'Sealdah', 4, '23:00:00', NULL),
(13, 4, 'Mumbai Central', 1, '06:00:00', '06:05:00'),
(14, 4, 'Surat', 2, '12:00:00', '12:05:00'),
(15, 4, 'Vadodara Junction', 3, '18:00:00', '18:05:00'),
(16, 4, 'New Delhi', 4, '23:00:00', NULL),
(17, 5, 'Mumbai CSMT', 1, '06:00:00', '06:05:00'),
(18, 5, 'Pune Junction', 2, '12:00:00', '12:05:00'),
(19, 5, 'Satara', 3, '18:00:00', '18:05:00'),
(20, 5, 'Goa', 4, '23:00:00', NULL),
(21, 6, 'Secunderabad', 1, '06:00:00', '06:05:00'),
(22, 6, 'Kacheguda', 2, '12:00:00', '12:05:00'),
(23, 6, 'Vijayawada', 3, '18:00:00', '18:05:00'),
(24, 6, 'Visakhapatnam', 4, '23:00:00', NULL),
(25, 7, 'Howrah', 1, '06:00:00', '06:05:00'),
(26, 7, 'Barddhaman', 2, '12:00:00', '12:05:00'),
(27, 7, 'Durgapur', 3, '18:00:00', '18:05:00'),
(28, 7, 'Asansol', 4, '23:00:00', NULL),
(29, 8, 'New Delhi', 1, '06:00:00', '06:05:00'),
(30, 8, 'Agra Cantt', 2, '12:00:00', '12:05:00'),
(31, 8, 'Gwalior', 3, '18:00:00', '18:05:00'),
(32, 8, 'Jhansi', 4, '23:00:00', NULL),
(33, 9, 'New Delhi', 1, '06:00:00', '06:05:00'),
(34, 9, 'Ujjain Junction', 2, '12:00:00', '12:05:00'),
(35, 9, 'Bhopal Junction', 3, '18:00:00', '18:05:00'),
(36, 9, 'Varanasi Junction', 4, '23:00:00', NULL),
(37, 10, 'Mumbai Central', 1, '06:00:00', '06:05:00'),
(38, 10, 'Vapi', 2, '12:00:00', '12:05:00'),
(39, 10, 'Surat', 3, '18:00:00', '18:05:00'),
(40, 10, 'Vadodara Junction', 4, '23:00:00', NULL),
(41, 11, 'Mumbai CST', 1, '06:00:00', '06:05:00'),
(42, 11, 'Kalyan Junction', 2, '12:00:00', '12:05:00'),
(43, 11, 'Nashik Road', 3, '18:00:00', '18:05:00'),
(44, 11, 'Pune Junction', 4, '23:00:00', NULL),
(45, 12, 'Ernakulam Junction', 1, '06:00:00', '06:05:00'),
(46, 12, 'Mangalore Junction', 2, '12:00:00', '12:05:00'),
(47, 12, 'Madgaon', 3, '18:00:00', '18:05:00'),
(48, 12, 'Mumbai LTT', 4, '23:00:00', NULL),
(49, 13, 'New Delhi', 1, '06:00:00', '06:05:00'),
(50, 13, 'Nagpur Junction', 2, '12:00:00', '12:05:00'),
(51, 13, 'Vijayawada', 3, '18:00:00', '18:05:00'),
(52, 13, 'Ernakulam Junction', 4, '23:00:00', NULL),
(53, 14, 'New Delhi', 1, '06:00:00', '06:05:00'),
(54, 14, 'Agra Cantt', 2, '12:00:00', '12:05:00'),
(55, 14, 'Bhopal Junction', 3, '18:00:00', '18:05:00'),
(56, 14, 'Chennai Central', 4, '23:00:00', NULL),
(57, 15, 'New Delhi', 1, '06:00:00', '06:05:00'),
(58, 15, 'Mathura Junction', 2, '12:00:00', '12:05:00'),
(59, 15, 'Bhopal Junction', 3, '18:00:00', '18:05:00'),
(60, 15, 'Chennai Central', 4, '23:00:00', NULL),
(61, 16, 'Chennai Central', 1, '06:00:00', '06:05:00'),
(62, 16, 'Vijayawada', 2, '12:00:00', '12:05:00'),
(63, 16, 'Nagpur Junction', 3, '18:00:00', '18:05:00'),
(64, 16, 'Hazrat Nizamuddin', 4, '23:00:00', NULL),
(65, 17, 'New Delhi', 1, '06:00:00', '06:05:00'),
(66, 17, 'Ambala Cantt', 2, '12:00:00', '12:05:00'),
(67, 17, 'Ludhiana Junction', 3, '18:00:00', '18:05:00'),
(68, 17, 'Amritsar Junction', 4, '23:00:00', NULL),
(69, 18, 'Vasco da Gama', 1, '06:00:00', '06:05:00'),
(70, 18, 'Madgaon', 2, '12:00:00', '12:05:00'),
(71, 18, 'Ratnagiri', 3, '18:00:00', '18:05:00'),
(72, 18, 'Mumbai Bandra Terminus', 4, '23:00:00', NULL),
(73, 19, 'Sealdah', 1, '06:00:00', '06:05:00'),
(74, 19, 'Malda Town', 2, '12:00:00', '12:05:00'),
(75, 19, 'New Jalpaiguri', 3, '18:00:00', '18:05:00'),
(76, 19, 'Siliguri Junction', 4, '23:00:00', NULL),
(77, 20, 'Sealdah', 1, '06:00:00', '06:05:00'),
(78, 20, 'Barddhaman', 2, '12:00:00', '12:05:00'),
(79, 20, 'Malda Town', 3, '18:00:00', '18:05:00'),
(80, 20, 'New Jalpaiguri', 4, '23:00:00', NULL),
(81, 21, 'Delhi Safdarjung', 1, '06:00:00', '06:05:00'),
(82, 21, 'Jaipur Junction', 2, '12:00:00', '12:05:00'),
(83, 21, 'Chittaurgarh', 3, '18:00:00', '18:05:00'),
(84, 21, 'Udaipur City', 4, '23:00:00', NULL),
(85, 22, 'Howrah', 1, '06:00:00', '06:05:00'),
(86, 22, 'Asansol', 2, '12:00:00', '12:05:00'),
(87, 22, 'Dhanbad Junction', 3, '18:00:00', '18:05:00'),
(88, 22, 'Kalka', 4, '23:00:00', NULL),
(89, 23, 'Mumbai CST', 1, '06:00:00', '06:05:00'),
(90, 23, 'Pune Junction', 2, '12:00:00', '12:05:00'),
(91, 23, 'Hyderabad Deccan', 3, '18:00:00', '18:05:00'),
(92, 23, 'Chennai Central', 4, '23:00:00', NULL),
(93, 24, 'Hazrat Nizamuddin', 1, '06:00:00', '06:05:00'),
(94, 24, 'Mathura Cantt', 2, '12:00:00', '12:05:00'),
(95, 24, 'Jaipur Junction', 3, '18:00:00', '18:05:00'),
(96, 24, 'Ajmer Junction', 4, '23:00:00', NULL),
(97, 25, 'Ernakulam Junction', 1, '06:00:00', '06:05:00'),
(98, 25, 'Kozhikode', 2, '12:00:00', '12:05:00'),
(99, 25, 'Kannur', 3, '18:00:00', '18:05:00'),
(100, 25, 'Mangalore Junction', 4, '23:00:00', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `seats`
--

DROP TABLE IF EXISTS `seats`;
CREATE TABLE `seats` (
  `trainid` int(11) NOT NULL,
  `available_sleeper` int(11) NOT NULL,
  `available_3ac` int(11) NOT NULL,
  `available_2ac` int(11) NOT NULL,
  `available_firstclass` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `seats`
--

INSERT INTO `seats` (`trainid`, `available_sleeper`, `available_3ac`, `available_2ac`, `available_firstclass`) VALUES
(1, 200, 100, 49, 0),
(2, 200, 100, 50, 20),
(3, 200, 100, 50, 20),
(4, 200, 100, 50, 20),
(5, 200, 99, 50, 20),
(6, 200, 99, 50, 20),
(7, 200, 100, 50, 20),
(8, 200, 100, 50, 20),
(9, 200, 100, 50, 20),
(10, 200, 100, 50, 20),
(11, 200, 100, 50, 20),
(12, 200, 100, 50, 20),
(13, 200, 100, 50, 20),
(14, 200, 100, 50, 20),
(15, 200, 100, 50, 20),
(16, 200, 100, 50, 20),
(17, 200, 100, 50, 20),
(18, 200, 100, 50, 20),
(19, 200, 100, 50, 20),
(20, 200, 100, 50, 20),
(21, 200, 100, 50, 20),
(22, 200, 100, 50, 20),
(23, 200, 100, 50, 20),
(24, 200, 100, 50, 20),
(25, 200, 100, 50, 20);

-- --------------------------------------------------------

--
-- Table structure for table `seat_class`
--

DROP TABLE IF EXISTS `seat_class`;
CREATE TABLE `seat_class` (
  `class_id` int(11) NOT NULL,
  `class_name` enum('sleeper','3ac','2ac','firstclass') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `seat_class`
--

INSERT INTO `seat_class` (`class_id`, `class_name`) VALUES
(1, 'sleeper'),
(2, '3ac'),
(3, '2ac'),
(4, 'firstclass');

-- --------------------------------------------------------

--
-- Table structure for table `tickets`
--

DROP TABLE IF EXISTS `tickets`;
CREATE TABLE `tickets` (
  `pnr` varchar(30) NOT NULL,
  `userid` int(11) NOT NULL,
  `trainid` int(11) NOT NULL,
  `class` enum('sleeper','3ac','2ac','firstclass') NOT NULL,
  `from_station` varchar(50) DEFAULT NULL,
  `to_station` varchar(50) DEFAULT NULL,
  `status` enum('confirmed','cancelled') DEFAULT 'confirmed',
  `amount` decimal(10,2) NOT NULL,
  `seat_no` int(11) DEFAULT NULL,
  `coach_no` varchar(10) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tickets`
--

INSERT INTO `tickets` (`pnr`, `userid`, `trainid`, `class`, `from_station`, `to_station`, `status`, `amount`, `seat_no`, `coach_no`) VALUES
('PNR11745421477182', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 320.00, 1, 'A'),
('PNR11745421538685', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 2, 'A'),
('PNR11745421552577', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 3, 'A'),
('PNR11745421690181', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 160.00, 6, 'A'),
('PNR11745421690352', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 240.00, 5, 'A'),
('PNR11745421690527', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 4, 'A'),
('PNR11745421707707', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 240.00, 8, 'A'),
('PNR11745421707919', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 7, 'A'),
('PNR11745421708777', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 160.00, 9, 'A'),
('PNR11745421716285', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 240.00, 11, 'A'),
('PNR11745421716391', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 160.00, 12, 'A'),
('PNR11745421716679', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 10, 'A'),
('PNR11745421805218', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 13, 'A'),
('PNR1174542180556', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 240.00, 14, 'A'),
('PNR11745421805624', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 160.00, 15, 'A'),
('PNR11745421812285', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 240.00, 17, 'A'),
('PNR11745421812566', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 160.00, 18, 'A'),
('PNR11745421812953', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 16, 'A'),
('PNR11745421821493', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 160.00, 20, 'A'),
('PNR11745421821628', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'confirmed', 400.00, 19, 'A'),
('PNR11745529997203', 5, 1, '2ac', 'New Delhi', 'Howrah', 'confirmed', 240.00, 1, 'A'),
('PNR51745530210637', 4, 5, '3ac', 'Pune Junction', 'Goa', 'confirmed', 120.00, 1, 'A'),
('PNR61745529539493', 4, 6, '3ac', 'Secunderabad', 'Vijayawada', 'confirmed', 160.00, 1, 'A');

-- --------------------------------------------------------

--
-- Table structure for table `trains`
--

DROP TABLE IF EXISTS `trains`;
CREATE TABLE `trains` (
  `trainid` int(11) NOT NULL,
  `train_name` varchar(100) NOT NULL,
  `max_sleeper` int(11) NOT NULL,
  `max_3ac` int(11) NOT NULL,
  `max_2ac` int(11) NOT NULL,
  `max_firstclass` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `trains`
--

INSERT INTO `trains` (`trainid`, `train_name`, `max_sleeper`, `max_3ac`, `max_2ac`, `max_firstclass`) VALUES
(1, 'Rajdhani Express', 200, 100, 50, 20),
(2, 'Shatabdi Express', 200, 100, 50, 20),
(3, 'Duronto Express', 200, 100, 50, 20),
(4, 'Garib Rath Express', 200, 100, 50, 20),
(5, 'Tejas Express', 200, 100, 50, 20),
(6, 'Humsafar Express', 200, 100, 50, 20),
(7, 'Double Decker Express', 200, 100, 50, 20),
(8, 'Vande Bharat Express', 200, 100, 50, 20),
(9, 'Mahamana Express', 200, 100, 50, 20),
(10, 'Flying Ranee', 200, 100, 50, 20),
(11, 'Deccan Queen', 200, 100, 50, 20),
(12, 'Mangala Lakshadweep Express', 200, 100, 50, 20),
(13, 'Kerala Express', 200, 100, 50, 20),
(14, 'Grand Trunk Express', 200, 100, 50, 20),
(15, 'Tamil Nadu Express', 200, 100, 50, 20),
(16, 'Andaman Express', 200, 100, 50, 20),
(17, 'Amritsar Express', 200, 100, 50, 20),
(18, 'Goa Express', 200, 100, 50, 20),
(19, 'Kanchenjunga Express', 200, 100, 50, 20),
(20, 'Darjeeling Mail', 200, 100, 50, 20),
(21, 'Palace on Wheels', 200, 100, 50, 20),
(22, 'Kalka Mail', 200, 100, 50, 20),
(23, 'Chennai Mail', 200, 100, 50, 20),
(24, 'Janshatabdi Express', 200, 100, 50, 20),
(25, 'Antyodaya Express', 200, 100, 50, 20);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `userid` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('user','admin') DEFAULT 'user'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`userid`, `name`, `email`, `password`, `role`) VALUES
(1, 'Dhanush', 'dhanush@example.com', 'password1', 'user'),
(2, 'Vineel', 'vineel@example.com', 'password2', 'user'),
(3, 'Guna', 'guna@example.com', 'password3', 'user'),
(4, 'Guna', 'hello12@gmail.com', '$2y$10$fyip/Xq3WuOTMPPKG3g40eiHR.pbhm4HvDlsYLdguTomYRcwBBe2u', 'user'),
(5, 'Dhanush', 'jiangly@gmail.com', '$2y$10$76aRdtcpa64cFug5ZYYeSuNEr1OwToz8fjEVolB98LxjMOdupoGrC', 'user'),
(6, 'Sridhanush', 'hadscdcsx@gmail.com', '$2y$10$WOIHqT9pjl/JWLBM4N.5Jupzx6s.qbWlnsdCvPpyjqQEVfZiCau12', 'user'),
(7, 'sanjay', 'dasu@gmail.com', '$2y$10$unmS.Wi6fMp94Ug6h1QkhOLoZjMJgfNSc.utitrCSGnipnZ.D03TS', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `waiting_list`
--

DROP TABLE IF EXISTS `waiting_list`;
CREATE TABLE `waiting_list` (
  `pnr` varchar(30) NOT NULL,
  `userid` int(11) NOT NULL,
  `trainid` int(11) NOT NULL,
  `class` enum('sleeper','3ac','2ac','firstclass') NOT NULL,
  `from_station` varchar(50) DEFAULT NULL,
  `to_station` varchar(50) DEFAULT NULL,
  `status` enum('active','cancelled') DEFAULT 'active',
  `amount` decimal(10,2) NOT NULL,
  `waiting_list_no` int(11) DEFAULT NULL COMMENT 'Position in waiting list'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `waiting_list`
--

INSERT INTO `waiting_list` (`pnr`, `userid`, `trainid`, `class`, `from_station`, `to_station`, `status`, `amount`, `waiting_list_no`) VALUES
('PNR11745421887643', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 2),
('PNR11745421887749', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 4),
('PNR11745421887935', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 3),
('PNR11745421894550', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 6),
('PNR11745421894629', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 5),
('PNR11745421894860', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 7),
('PNR11745421901240', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 10),
('PNR11745421901377', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 8),
('PNR1174542190174', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 9),
('PNR11745421908168', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 12),
('PNR11745421908181', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 11),
('PNR11745421908298', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 13),
('PNR11745421917132', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 16),
('PNR11745421917150', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 15),
('PNR11745421917539', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 14),
('PNR11745421985312', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 17),
('PNR11745421986584', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 19),
('PNR11745421986904', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 18),
('PNR1174542199313', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 22),
('PNR11745421993297', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 20),
('PNR11745421993981', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 21),
('PNR11745422167166', 1, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 160.00, 23),
('PNR11745422167615', 2, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 320.00, 24),
('PNR11745422168576', 3, 1, 'firstclass', 'Delhi', 'Kolkata', 'active', 400.00, 25);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `passengers`
--
ALTER TABLE `passengers`
  ADD PRIMARY KEY (`passenger_id`),
  ADD UNIQUE KEY `pnr` (`pnr`),
  ADD KEY `trainid` (`trainid`);

--
-- Indexes for table `payment`
--
ALTER TABLE `payment`
  ADD PRIMARY KEY (`payment_id`),
  ADD KEY `userid` (`userid`),
  ADD KEY `trainid` (`trainid`);

--
-- Indexes for table `rac`
--
ALTER TABLE `rac`
  ADD PRIMARY KEY (`pnr`),
  ADD KEY `userid` (`userid`),
  ADD KEY `trainid` (`trainid`);

--
-- Indexes for table `refund`
--
ALTER TABLE `refund`
  ADD PRIMARY KEY (`pnr`),
  ADD KEY `userid` (`userid`),
  ADD KEY `trainid` (`trainid`);

--
-- Indexes for table `routes`
--
ALTER TABLE `routes`
  ADD PRIMARY KEY (`routeid`),
  ADD KEY `trainid` (`trainid`);

--
-- Indexes for table `route_stops`
--
ALTER TABLE `route_stops`
  ADD PRIMARY KEY (`stopid`),
  ADD UNIQUE KEY `routeid` (`routeid`,`stop_order`),
  ADD UNIQUE KEY `routeid_2` (`routeid`,`station_name`,`stop_order`);

--
-- Indexes for table `seats`
--
ALTER TABLE `seats`
  ADD PRIMARY KEY (`trainid`);

--
-- Indexes for table `seat_class`
--
ALTER TABLE `seat_class`
  ADD PRIMARY KEY (`class_id`),
  ADD UNIQUE KEY `class_name` (`class_name`);

--
-- Indexes for table `tickets`
--
ALTER TABLE `tickets`
  ADD PRIMARY KEY (`pnr`),
  ADD KEY `userid` (`userid`),
  ADD KEY `trainid` (`trainid`);

--
-- Indexes for table `trains`
--
ALTER TABLE `trains`
  ADD PRIMARY KEY (`trainid`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`userid`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `waiting_list`
--
ALTER TABLE `waiting_list`
  ADD PRIMARY KEY (`pnr`),
  ADD KEY `userid` (`userid`),
  ADD KEY `trainid` (`trainid`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `passengers`
--
ALTER TABLE `passengers`
  MODIFY `passenger_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=59;

--
-- AUTO_INCREMENT for table `payment`
--
ALTER TABLE `payment`
  MODIFY `payment_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT for table `routes`
--
ALTER TABLE `routes`
  MODIFY `routeid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `route_stops`
--
ALTER TABLE `route_stops`
  MODIFY `stopid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=101;

--
-- AUTO_INCREMENT for table `seat_class`
--
ALTER TABLE `seat_class`
  MODIFY `class_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `trains`
--
ALTER TABLE `trains`
  MODIFY `trainid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `userid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `passengers`
--
ALTER TABLE `passengers`
  ADD CONSTRAINT `passengers_ibfk_1` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON UPDATE CASCADE;

--
-- Constraints for table `payment`
--
ALTER TABLE `payment`
  ADD CONSTRAINT `payment_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`userid`) ON UPDATE CASCADE,
  ADD CONSTRAINT `payment_ibfk_2` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON UPDATE CASCADE;

--
-- Constraints for table `rac`
--
ALTER TABLE `rac`
  ADD CONSTRAINT `rac_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`userid`) ON UPDATE CASCADE,
  ADD CONSTRAINT `rac_ibfk_2` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON UPDATE CASCADE;

--
-- Constraints for table `refund`
--
ALTER TABLE `refund`
  ADD CONSTRAINT `refund_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`userid`) ON UPDATE CASCADE,
  ADD CONSTRAINT `refund_ibfk_2` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON UPDATE CASCADE;

--
-- Constraints for table `routes`
--
ALTER TABLE `routes`
  ADD CONSTRAINT `routes_ibfk_1` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `route_stops`
--
ALTER TABLE `route_stops`
  ADD CONSTRAINT `route_stops_ibfk_1` FOREIGN KEY (`routeid`) REFERENCES `routes` (`routeid`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `seats`
--
ALTER TABLE `seats`
  ADD CONSTRAINT `seats_ibfk_1` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `tickets`
--
ALTER TABLE `tickets`
  ADD CONSTRAINT `tickets_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`userid`) ON UPDATE CASCADE,
  ADD CONSTRAINT `tickets_ibfk_2` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON UPDATE CASCADE;

--
-- Constraints for table `waiting_list`
--
ALTER TABLE `waiting_list`
  ADD CONSTRAINT `waiting_list_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `users` (`userid`) ON UPDATE CASCADE,
  ADD CONSTRAINT `waiting_list_ibfk_2` FOREIGN KEY (`trainid`) REFERENCES `trains` (`trainid`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
