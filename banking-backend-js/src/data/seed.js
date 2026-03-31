const seed = {
  customersDb: {
    "CUST-BR-001": {
      customerId: "CUST-BR-001",
      cpf: "11122233344",
      name: "Beatriz Costa",
      kycStatus: "VERIFIED",
      riskRating: "LOW",
      preferredBranchId: "BR-SP-001",
      accounts: ["ACC-CHK-BR-001", "ACC-SAV-BR-001"],
      cards: ["CARD-CR-BR-001"]
    },
    "CUST-BR-002": {
      customerId: "CUST-BR-002",
      cpf: "55566677788",
      name: "Daniel Martins",
      kycStatus: "PENDING_REVIEW",
      riskRating: "MEDIUM",
      preferredBranchId: "BR-RJ-001",
      accounts: ["ACC-CHK-BR-002"],
      cards: ["CARD-DB-BR-002"]
    },
    "CUST-BR-003": {
      customerId: "CUST-BR-003",
      cpf: "99988877766",
      name: "Fernanda Lima",
      kycStatus: "VERIFIED",
      riskRating: "HIGH",
      preferredBranchId: "BR-MG-001",
      accounts: ["ACC-CHK-BR-003"],
      cards: ["CARD-CR-BR-003"]
    }
  },

  accountsDb: {
    "ACC-CHK-BR-001": {
      accountId: "ACC-CHK-BR-001",
      customerId: "CUST-BR-001",
      accountType: "CHECKING",
      currency: "BRL",
      availableBalance: 12540.33,
      ledgerBalance: 12540.33,
      status: "ACTIVE",
      dailyPixLimit: 5000,
      branchId: "BR-SP-001",
      lastUpdatedAt: "2026-03-15T09:00:00.000Z"
    },
    "ACC-SAV-BR-001": {
      accountId: "ACC-SAV-BR-001",
      customerId: "CUST-BR-001",
      accountType: "SAVINGS",
      currency: "BRL",
      availableBalance: 40000,
      ledgerBalance: 40000,
      status: "ACTIVE",
      dailyPixLimit: 0,
      branchId: "BR-SP-001",
      lastUpdatedAt: "2026-03-15T09:00:00.000Z"
    },
    "ACC-CHK-BR-002": {
      accountId: "ACC-CHK-BR-002",
      customerId: "CUST-BR-002",
      accountType: "CHECKING",
      currency: "BRL",
      availableBalance: 850.9,
      ledgerBalance: 850.9,
      status: "ACTIVE",
      dailyPixLimit: 1200,
      branchId: "BR-RJ-001",
      lastUpdatedAt: "2026-03-15T09:30:00.000Z"
    },
    "ACC-CHK-BR-003": {
      accountId: "ACC-CHK-BR-003",
      customerId: "CUST-BR-003",
      accountType: "CHECKING",
      currency: "BRL",
      availableBalance: 150000,
      ledgerBalance: 150000,
      status: "ACTIVE",
      dailyPixLimit: 10000,
      branchId: "BR-MG-001",
      lastUpdatedAt: "2026-03-15T10:00:00.000Z"
    }
  },

  cardsDb: {
    "CARD-CR-BR-001": {
      cardId: "CARD-CR-BR-001",
      customerId: "CUST-BR-001",
      cardType: "CREDIT",
      network: "VISA",
      status: "ACTIVE",
      limit: 18000,
      availableLimit: 13250,
      embossedName: "BEATRIZ COSTA",
      last4: "1122",
      internationalEnabled: true,
      lastUpdatedAt: "2026-03-15T11:00:00.000Z"
    },
    "CARD-DB-BR-002": {
      cardId: "CARD-DB-BR-002",
      customerId: "CUST-BR-002",
      cardType: "DEBIT",
      network: "MASTERCARD",
      status: "ACTIVE",
      limit: 0,
      availableLimit: 0,
      embossedName: "DANIEL MARTINS",
      last4: "2211",
      internationalEnabled: false,
      lastUpdatedAt: "2026-03-15T11:05:00.000Z"
    },
    "CARD-CR-BR-003": {
      cardId: "CARD-CR-BR-003",
      customerId: "CUST-BR-003",
      cardType: "CREDIT",
      network: "ELO",
      status: "TEMP_BLOCKED",
      limit: 45000,
      availableLimit: 44000,
      embossedName: "FERNANDA LIMA",
      last4: "7788",
      internationalEnabled: true,
      lastUpdatedAt: "2026-03-15T11:10:00.000Z"
    }
  },

  paymentsStore: {
    "PMT-PIX-20260315-0001": {
      paymentId: "PMT-PIX-20260315-0001",
      accountId: "ACC-CHK-BR-001",
      paymentRail: "PIX",
      beneficiaryName: "Utility Company",
      beneficiaryBank: "BRASIL_ENERGIA",
      amountBr: 230.55,
      status: "SETTLED",
      createdAt: "2026-03-15T12:00:00.000Z",
      lastUpdatedAt: "2026-03-15T12:01:00.000Z"
    }
  },

  transfersStore: {
    "TRF-20260315-0001": {
      transferId: "TRF-20260315-0001",
      fromAccountId: "ACC-CHK-BR-003",
      toBankCode: "237",
      toAccountMasked: "****4321",
      amountBr: 25000,
      channel: "APP",
      status: "PENDING_REVIEW",
      createdAt: "2026-03-15T13:00:00.000Z",
      lastUpdatedAt: "2026-03-15T13:00:00.000Z"
    }
  },

  complianceEvents: [],
  fraudAlerts: [],
  processorEvents: []
};

module.exports = { seed };
