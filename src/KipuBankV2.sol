// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

type AccountId is bytes32;

enum Currency {
    NATIVE, // ETH (wei)
    USD     // valor contabilizado con 10^USD_DECIMALS
}

struct Ledger {
    uint256 balance;
    uint40  lastUpdated;
}

error NotAdmin();
error NotTeller();
error ZeroAddress();
error ZeroAmount();
error ExceedsLimit();
error InsufficientBalance();
error StaleOracle();
error InvalidDecimals();

contract KipuBankV2 {
    // ---- Control de acceso simple ----
    mapping(address => bool) private _admins;
    mapping(address => bool) private _tellers;

    modifier onlyAdmin() {
        if (!_admins[msg.sender]) revert NotAdmin();
        _;
    }

    modifier onlyTeller() {
        if (!_tellers[msg.sender]) revert NotTeller();
        _;
    }

    // ---- Oráculo Chainlink ----
    AggregatorV3Interface public immutable priceFeed; // p.ej., ETH/USD
    uint8 public immutable ORACLE_DECIMALS;

    // ---- Constantes ----
    uint8   public constant USD_DECIMALS = 8;
    uint256 public constant MAX_DEPOSIT_WEI = 100 ether;
    bytes32 public constant VERSION = keccak256("KipuBankV2:1.0.0");

    // ---- Mappings anidados ----
    mapping(address => mapping(Currency => Ledger)) private _book;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---- Eventos ----
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);
    event TellerAdded(address indexed account);
    event TellerRemoved(address indexed account);

    event Deposit(address indexed user, uint256 amountWei, uint256 newBalanceWei);
    event Withdraw(address indexed user, uint256 amountWei, uint256 newBalanceWei);
    event AllowanceApproved(address indexed owner, address indexed spender, uint256 amount);
    event TransferFrom(address indexed owner, address indexed to, uint256 amountWei);

    constructor(address initialAdmin, address feedAddress) {
        if (initialAdmin == address(0) || feedAddress == address(0)) revert ZeroAddress();
        _admins[initialAdmin] = true;
        emit AdminAdded(initialAdmin);

        priceFeed = AggregatorV3Interface(feedAddress);
        ORACLE_DECIMALS = priceFeed.decimals();
    }

    // ---- Gestión de roles ----
    function addAdmin(address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        _admins[account] = true;
        emit AdminAdded(account);
    }

    function removeAdmin(address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        _admins[account] = false;
        emit AdminRemoved(account);
    }

    function addTeller(address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        _tellers[account] = true;
        emit TellerAdded(account);
    }

    function removeTeller(address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        _tellers[account] = false;
        emit TellerRemoved(account);
    }

    // ---- Bóveda: depósito / retiro ----
    function deposit() external payable {
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroAmount();
        if (amount > MAX_DEPOSIT_WEI) revert ExceedsLimit();

        Ledger storage L = _book[msg.sender][Currency.NATIVE];
        L.balance += amount;
        L.lastUpdated = uint40(block.timestamp);

        emit Deposit(msg.sender, amount, L.balance);
    }

    function withdraw(uint256 amountWei) external {
        if (amountWei == 0) revert ZeroAmount();

        Ledger storage L = _book[msg.sender][Currency.NATIVE];
        if (L.balance < amountWei) revert InsufficientBalance();

        L.balance -= amountWei;
        L.lastUpdated = uint40(block.timestamp);

        (bool ok, ) = msg.sender.call{value: amountWei}("");
        require(ok, "ETH transfer failed");

        emit Withdraw(msg.sender, amountWei, L.balance);
    }

    // ---- Allowance estilo "teller" o autorizado ----
    function approve(address spender, uint256 amountWei) external {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amountWei;
        emit AllowanceApproved(msg.sender, spender, amountWei);
    }

    function transferFrom(address owner, address to, uint256 amountWei) external {
        if (owner == address(0) || to == address(0)) revert ZeroAddress();
        if (amountWei == 0) revert ZeroAmount();

        uint256 cur = allowance[owner][msg.sender];
        require(cur >= amountWei, "insufficient allowance");

        Ledger storage L = _book[owner][Currency.NATIVE];
        if (L.balance < amountWei) revert InsufficientBalance();

        // mover saldo interno
        L.balance -= amountWei;
        _book[to][Currency.NATIVE].balance += amountWei;
        _book[to][Currency.NATIVE].lastUpdated = uint40(block.timestamp);

        // disminuir allowance
        allowance[owner][msg.sender] = cur - amountWei;

        emit TransferFrom(owner, to, amountWei);
    }

    // ---- Vistas ----
    function balanceOf(address user) external view returns (uint256 weiBalance) {
        return _book[user][Currency.NATIVE].balance;
    }

    /// @notice Retorna el valor aproximado en USD (USD_DECIMALS) del balance en ETH (usando Chainlink)
    function balanceInUSD(address user) external view returns (uint256 usdAmount) {
        uint256 weiBal = _book[user][Currency.NATIVE].balance;
        if (weiBal == 0) return 0;
        return quoteNativeToUSD(weiBal);
    }

    // ---- Conversión de decimales y cotización ----

    /// @notice Convierte un valor entre diferentes escalas de decimales.
    /// @dev Útil para homogeneizar unidades (wei:18, oráculo: ORACLE_DECIMALS, USD_DECIMALS:8)
    function convertDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) public pure returns (uint256) {
        if (fromDecimals == toDecimals) return amount;
        if (fromDecimals > 77 || toDecimals > 77) revert InvalidDecimals(); // guardia
        if (fromDecimals < toDecimals) {
            uint8 diff = toDecimals - fromDecimals;
            return amount * (10 ** diff);
        } else {
            uint8 diff = fromDecimals - toDecimals;
            return amount / (10 ** diff);
        }
    }

    /// @notice Cotiza un monto en wei a USD con decimales USD_DECIMALS usando el oráculo.
    /// @dev price = ETH/USD con ORACLE_DECIMALS; resultado en 10^USD_DECIMALS
    function quoteNativeToUSD(uint256 weiAmount) public view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        require(answer > 0, "invalid oracle price");

        // anti-staleness (opcional; 1 hora)
        if (block.timestamp - updatedAt > 1 hours) revert StaleOracle();

        // Normalizar: wei (18) * precio(ORACLE_DECIMALS) -> USD_DECIMALS
        // usd = (wei * price) ajustando decimales:
        //   wei(18) -> ORACLE_DECIMALS + USD_DECIMALS para mantener precisión antes de dividir
        // Implementación: (wei * price) / 10^(18-USD_DECIMALS) si ORACLE_DECIMALS == USD_DECIMALS
        // Generalizamos vía convertDecimals

        // (wei -> 18), price -> ORACLE_DECIMALS
        // Queremos resultado en USD_DECIMALS:
        // Primero pasamos wei a una base común sumando decimales y luego reescalamos.
        // Más directo: (wei * price) con 18 + ORACLE_DECIMALS -> luego bajar a USD_DECIMALS.
        uint256 priceU = uint256(answer);

        // Multiplicación con verificación básica para evitar overflow improbable (no necesaria en 0.8+, pero clara)
        unchecked {
            uint256 num = weiAmount * priceU; // 18 + ORACLE_DECIMALS
            // Reducimos de (18 + ORACLE_DECIMALS) a USD_DECIMALS
            uint8 from = uint8(18 + ORACLE_DECIMALS);
            if (from >= USD_DECIMALS) {
                return convertDecimals(num, from, USD_DECIMALS);
            } else {
                // extremadamente raro, pero por completitud
                return convertDecimals(num, from, USD_DECIMALS);
            }
        }
    }

    // ---- Funciones privadas auxiliares ----

    /// @dev Crea un AccountId determinístico para un address.
    function _toAccountId(address user) private pure returns (AccountId) {
        return AccountId.wrap(keccak256(abi.encodePacked(user)));
    }

    // ---- Helpers públicos de rol (solo lectura) ----
    function isAdmin(address account) external view returns (bool) {
        return _admins[account];
    }

    function isTeller(address account) external view returns (bool) {
        return _tellers[account];
    }

    // permitir recibir ETH directo
    receive() external payable {
        // trata cualquier envío directo como depósito del remitente
        if (msg.value == 0) return;
        Ledger storage L = _book[msg.sender][Currency.NATIVE];
        L.balance += msg.value;
        L.lastUpdated = uint40(block.timestamp);
        emit Deposit(msg.sender, msg.value, L.balance);
    }
}

