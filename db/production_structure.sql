CREATE TABLE `boards` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL,
  `decree_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `finalizer_user_id` int(10) DEFAULT NULL,
  `identifier_classes` text,
  `rank` int(10) DEFAULT NULL,
  `friendly_name` varchar(255) DEFAULT NULL,
  `community_id` int(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `boards_users` (
  `board_id` int(10) DEFAULT NULL,
  `user_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  UNIQUE KEY `index_boards_users_on_board_id_and_user_id` (`board_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `comment` text,
  `user_id` int(10) DEFAULT NULL,
  `identifier_id` int(10) DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `git_hash` varchar(255) DEFAULT NULL,
  `publication_id` int(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `communities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `friendly_name` varchar(255) DEFAULT NULL,
  `members` int(10) DEFAULT NULL,
  `admins` int(10) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `board_id` int(10) DEFAULT NULL,
  `publication_id` int(10) DEFAULT NULL,
  `end_user_id` int(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `communities_admins` (
  `community_id` int(10) DEFAULT NULL,
  `user_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `communities_members` (
  `community_id` int(10) DEFAULT NULL,
  `user_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `decrees` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `action` varchar(255) DEFAULT NULL,
  `trigger` decimal(5,2) DEFAULT NULL,
  `choices` varchar(255) DEFAULT NULL,
  `board_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `tally_method` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `docos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `line` decimal(7,2) DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `preview` varchar(255) DEFAULT NULL,
  `leiden` varchar(255) DEFAULT NULL,
  `xml` varchar(255) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `urldisplay` varchar(255) DEFAULT NULL,
  `note` text,
  `docotype` varchar(255) NOT NULL DEFAULT 'text',
  PRIMARY KEY (`id`),
  KEY `index_docos_on_docotype` (`docotype`),
  KEY `index_docos_on_id_and_docotype` (`docotype`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `emailers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `board_id` int(10) DEFAULT NULL,
  `user_id` int(10) DEFAULT NULL,
  `extra_addresses` text,
  `when_to_send` varchar(255) DEFAULT NULL,
  `include_document` tinyint(1) DEFAULT NULL,
  `message` text,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `send_to_owner` tinyint(1) DEFAULT NULL,
  `send_to_all_board_members` tinyint(1) DEFAULT '0',
  `include_comments` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `emailers_users` (
  `emailer_id` varchar(255) DEFAULT NULL,
  `user_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  UNIQUE KEY `index_emailers_users_on_emailer_id_and_user_id` (`emailer_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `events` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `category` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `owner_id` int(10) DEFAULT NULL,
  `owner_type` varchar(255) DEFAULT NULL,
  `target_id` int(10) DEFAULT NULL,
  `target_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `identifiers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `publication_id` int(10) DEFAULT NULL,
  `alternate_name` varchar(255) DEFAULT NULL,
  `modified` tinyint(1) DEFAULT '0',
  `title` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT 'editing',
  `board_id` int(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `publications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `owner_id` int(10) DEFAULT NULL,
  `owner_type` varchar(255) DEFAULT NULL,
  `branch` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT 'editing',
  `creator_id` int(10) DEFAULT NULL,
  `creator_type` varchar(255) DEFAULT NULL,
  `parent_id` int(10) DEFAULT NULL,
  `community_id` int(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_identifiers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(255) DEFAULT NULL,
  `user_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `has_repository` tinyint(1) DEFAULT '0',
  `language_prefs` varchar(255) DEFAULT NULL,
  `admin` tinyint(1) DEFAULT NULL,
  `developer` tinyint(1) DEFAULT NULL,
  `affiliation` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `emailer_id` int(10) DEFAULT NULL,
  `full_name` varchar(255) DEFAULT NULL,
  `is_community_master_admin` tinyint(1) DEFAULT '0',
  `is_master_admin` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `votes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `choice` varchar(255) DEFAULT NULL,
  `user_id` int(10) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `publication_id` int(10) DEFAULT NULL,
  `identifier_id` int(10) DEFAULT NULL,
  `board_id` int(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO schema_migrations (version) VALUES ('20081111161656');

INSERT INTO schema_migrations (version) VALUES ('20090123200908');

INSERT INTO schema_migrations (version) VALUES ('20090203185629');

INSERT INTO schema_migrations (version) VALUES ('20090209160712');

INSERT INTO schema_migrations (version) VALUES ('20090219214600');

INSERT INTO schema_migrations (version) VALUES ('20090303201719');

INSERT INTO schema_migrations (version) VALUES ('20090303201909');

INSERT INTO schema_migrations (version) VALUES ('20090303201939');

INSERT INTO schema_migrations (version) VALUES ('20090303215658');

INSERT INTO schema_migrations (version) VALUES ('20090305024337');

INSERT INTO schema_migrations (version) VALUES ('20090306052257');

INSERT INTO schema_migrations (version) VALUES ('20090319212311');

INSERT INTO schema_migrations (version) VALUES ('20090323182009');

INSERT INTO schema_migrations (version) VALUES ('20090324192114');

INSERT INTO schema_migrations (version) VALUES ('20090327165214');

INSERT INTO schema_migrations (version) VALUES ('20090327165311');

INSERT INTO schema_migrations (version) VALUES ('20090401203640');

INSERT INTO schema_migrations (version) VALUES ('20090409191823');

INSERT INTO schema_migrations (version) VALUES ('20090409230112');

INSERT INTO schema_migrations (version) VALUES ('20090417204933');

INSERT INTO schema_migrations (version) VALUES ('20090420202625');

INSERT INTO schema_migrations (version) VALUES ('20090420214648');

INSERT INTO schema_migrations (version) VALUES ('20090422190506');

INSERT INTO schema_migrations (version) VALUES ('20090422194156');

INSERT INTO schema_migrations (version) VALUES ('20090423005730');

INSERT INTO schema_migrations (version) VALUES ('20090429181139');

INSERT INTO schema_migrations (version) VALUES ('20090429181443');

INSERT INTO schema_migrations (version) VALUES ('20090429182155');

INSERT INTO schema_migrations (version) VALUES ('20090429210048');

INSERT INTO schema_migrations (version) VALUES ('20090507180036');

INSERT INTO schema_migrations (version) VALUES ('20090514210236');

INSERT INTO schema_migrations (version) VALUES ('20090528165638');

INSERT INTO schema_migrations (version) VALUES ('20090528192227');

INSERT INTO schema_migrations (version) VALUES ('20090604145921');

INSERT INTO schema_migrations (version) VALUES ('20090604155626');

INSERT INTO schema_migrations (version) VALUES ('20090620155431');

INSERT INTO schema_migrations (version) VALUES ('20090916153409');

INSERT INTO schema_migrations (version) VALUES ('20090929170138');

INSERT INTO schema_migrations (version) VALUES ('20090930202845');

INSERT INTO schema_migrations (version) VALUES ('20091019182632');

INSERT INTO schema_migrations (version) VALUES ('20091021162523');

INSERT INTO schema_migrations (version) VALUES ('20091026160035');

INSERT INTO schema_migrations (version) VALUES ('20091105164204');

INSERT INTO schema_migrations (version) VALUES ('20091110204800');

INSERT INTO schema_migrations (version) VALUES ('20091111174622');

INSERT INTO schema_migrations (version) VALUES ('20091112215750');

INSERT INTO schema_migrations (version) VALUES ('20091113210934');

INSERT INTO schema_migrations (version) VALUES ('20091117193653');

INSERT INTO schema_migrations (version) VALUES ('20091202150900');

INSERT INTO schema_migrations (version) VALUES ('20091207163339');

INSERT INTO schema_migrations (version) VALUES ('20100120175728');

INSERT INTO schema_migrations (version) VALUES ('20100127044952');

INSERT INTO schema_migrations (version) VALUES ('20100203215323');

INSERT INTO schema_migrations (version) VALUES ('20100205163517');

INSERT INTO schema_migrations (version) VALUES ('20100205163546');

INSERT INTO schema_migrations (version) VALUES ('20100408204549');

INSERT INTO schema_migrations (version) VALUES ('20100422171330');

INSERT INTO schema_migrations (version) VALUES ('20100424033541');

INSERT INTO schema_migrations (version) VALUES ('20100820140941');

INSERT INTO schema_migrations (version) VALUES ('20110221221456');

INSERT INTO schema_migrations (version) VALUES ('20110303222737');

INSERT INTO schema_migrations (version) VALUES ('20110609190237');

INSERT INTO schema_migrations (version) VALUES ('20110609194943');

INSERT INTO schema_migrations (version) VALUES ('20110609195354');

INSERT INTO schema_migrations (version) VALUES ('20110610185437');

INSERT INTO schema_migrations (version) VALUES ('20110610190703');

INSERT INTO schema_migrations (version) VALUES ('20110613192147');

INSERT INTO schema_migrations (version) VALUES ('20110615210136');

INSERT INTO schema_migrations (version) VALUES ('20110630150541');

INSERT INTO schema_migrations (version) VALUES ('20110811204557');