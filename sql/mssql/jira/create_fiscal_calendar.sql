USE [CKB]
GO

/****** Object:  Table [jdacustom].[fiscal_calendar]    Script Date: 10/30/2019 5:00:33 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [jdacustom].[fiscal_calendar](
	[Date] [date] NOT NULL,
	[Year] [int] NOT NULL,
	[Quarter] [int] NOT NULL,
	[Period] [int] NOT NULL,
	[Week] [int] NOT NULL,
	[Day] [int] NOT NULL,
	[Julian] [int] NOT NULL,
 CONSTRAINT [pk_fiscal_calendar] PRIMARY KEY CLUSTERED 
(
	[Date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE UNIQUE NONCLUSTERED INDEX [idx_fiscal_calendar] ON [jdacustom].[fiscal_calendar]
(
	[Year] ASC,
	[Period] ASC,
	[Week] ASC,
	[Day] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO