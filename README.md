# 💰 KipuBankV2 — Bóveda Inteligente con Oráculo Chainlink

KipuBankV2 es una versión mejorada del contrato **KipuBank**, que actúa como una bóveda descentralizada para depósitos y retiros de ETH, con control de acceso por roles y cotización en tiempo real usando **Chainlink Price Feeds (ETH/USD)**.

El contrato permite administrar saldos internos de usuarios, consultar su valor en USD, y controlar permisos de operadores (“tellers”) sin comprometer la seguridad de los fondos.

---

## 🚀 Características principales

- ✅ **Control de acceso** con roles de `Admin` y `Teller`.  
- ✅ **Instancia del oráculo Chainlink** para obtener precios ETH/USD en tiempo real.  
- ✅ **Declaraciones de tipos personalizados** (`type`, `enum`, `struct`).  
- ✅ **Variables `constant` e `immutable`** para mayor eficiencia.  
- ✅ **Mappings anidados** (`mapping(address => mapping(Currency => Ledger))`).  
- ✅ **Conversión automática** entre decimales de ETH y USD.  
- ✅ **Funciones seguras y limpias**: `deposit`, `withdraw`, `balanceInUSD`, etc.  
- ✅ **Eventos y errores personalizados** para trazabilidad y claridad.

---

## ⚙️ Descripción técnica

- **Lenguaje:** Solidity `^0.8.24`
- **Oráculo Chainlink:** ETH/USD  
- **Red recomendada:** Sepolia Testnet (puede adaptarse a otras redes)
- **Precio de referencia:** tomado de `AggregatorV3Interface.latestRoundData()`
- **Monedas soportadas:** ETH (nativa) y USD (cotización virtual)
- **Control de acceso:**
  - `Admin`: puede agregar o quitar administradores y tellers.
  - `Teller`: operador autorizado para mover fondos de clientes (previa aprobación).

---

## 🧱 Instrucciones de despliegue

### 1. Compilación

1. Abre [Remix IDE](https://remix.ethereum.org/).
2. Carga el contrato `src/KipuBankV2.sol`.
3. En la pestaña **Solidity Compiler**, selecciona:
   - **Versión:** `0.8.24` o superior.
   - **Enable optimization:** ✅

---

### 2. Despliegue en testnet (Sepolia con MetaMask)

1. Cambia el entorno a:
2. Conéctate a la red **Sepolia Testnet**.
3. Solicita ETH de prueba en uno de estos faucets:
- 🔗 [https://faucet.chain.link/sepolia](https://faucet.chain.link/sepolia)
- 🔗 [https://sepoliafaucet.com](https://sepoliafaucet.com)
4. En Remix, en el constructor ingresa:
- `initialAdmin`: tu dirección (por ejemplo, la de MetaMask)
- `feedAddress`: **ETH/USD Sepolia Feed → `0x694AA1769357215DE4FAC081bf1f309aDC325306`**
5. Haz clic en **Deploy** y espera la confirmación.

---

## 💬 Interacción con el contrato

Una vez desplegado, podrás usar las siguientes funciones desde Remix o cualquier interfaz web3:

| Función | Tipo | Descripción |
|----------|------|-------------|
| `deposit()` | `external payable` | Envía ETH al contrato y actualiza tu saldo interno. |
| `withdraw(uint256 amountWei)` | `external` | Retira ETH de tu saldo interno. |
| `balanceOf(address user)` | `view` | Devuelve el saldo en wei (ETH). |
| `balanceInUSD(address user)` | `view` | Devuelve el valor equivalente en USD (usando Chainlink). |
| `addAdmin(address)` | `onlyAdmin` | Agrega un nuevo administrador. |
| `addTeller(address)` | `onlyAdmin` | Agrega un operador autorizado. |
| `approve(address spender, uint256 amount)` | `external` | Autoriza a un teller a mover tus fondos. |
| `transferFrom(address owner, address to, uint256 amount)` | `external` | Permite mover fondos internos (si fue aprobado). |
| `quoteNativeToUSD(uint256 weiAmount)` | `view` | Calcula el valor USD para cualquier cantidad de ETH. |

### Ejemplo rápido en Remix

1. **Depositar ETH**
- Abre `deposit()`
- En el campo “Value”, ingresa `1 ether`
- Ejecuta la función → se registra tu depósito

2. **Consultar saldo**
- Llama a `balanceOf(<tu address>)` → muestra tu saldo en wei

3. **Ver valor en USD**
- Llama a `balanceInUSD(<tu address>)` → valor calculado según el feed

4. **Retirar ETH**
- Llama a `withdraw(1000000000000000000)` → (1 ETH en wei)
- Recibirás el ETH de vuelta en tu cuenta

---

## 🧠 Notas de diseño

- El contrato usa **`immutable`** para variables del oráculo y **`constant`** para configuraciones estáticas, optimizando el gas.
- El **oráculo Chainlink** garantiza precisión y resistencia a manipulaciones de precio.
- Se aplican **modificadores de rol (`onlyAdmin`, `onlyTeller`)** para proteger funciones críticas.
- Los **errores personalizados** reducen gas y mejoran legibilidad (por ejemplo, `NotAdmin()`, `InsufficientBalance()`).
- El patrón **checks–effects–interactions** se respeta en los retiros.

---

## 🔒 Seguridad y consideraciones

- No usar este contrato en producción sin auditoría profesional.  
- Implementar **ReentrancyGuard** si se desea extender la lógica de retiro.  
- Mantener actualizadas las direcciones de oráculos si se migra de red.  
- No exponer claves privadas ni administrar fondos reales en redes principales.

---

## 🧾 Ejemplo de despliegue (Sepolia)

| Parámetro | Valor |
|------------|--------|
| `initialAdmin` | `0xC37...73d4a` |
| `feedAddress` | `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| **Contrato desplegado en:** | `0xYourContractAddressHere` |
| **Red:** | Sepolia Testnet |
| **Oráculo:** | Chainlink ETH/USD |

---

## 👨‍💻 Autor

**Christian Cañar**  
Proyecto académico: *KipuBankV2 – Contrato inteligente con integración Chainlink*  
© 2025 — Todos los derechos reservados.

