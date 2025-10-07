# 💰 KipuBankV2 — Contrato Inteligente Mejorado con Control de Acceso y Oráculo Chainlink

**KipuBankV2** es una evolución del contrato original **KipuBank**, diseñado para ofrecer una bóveda más segura, escalable y precisa mediante la integración de **control de acceso avanzado**, **tipos personalizados**, y **conversión de valores en tiempo real** utilizando **Chainlink Price Feeds (ETH/USD)**.

---

## 🚀 1. Mejoras realizadas y motivos

### 🔐 Control de acceso por roles (`Admin` y `Teller`)
- **Motivo:** En la versión original, cualquier usuario podía realizar operaciones básicas.  
- **Mejora:** Se implementó un sistema de roles mediante *modificadores* `onlyAdmin` y `onlyTeller`.  
  - Los administradores pueden agregar o eliminar otros administradores y operadores.  
  - Los *tellers* (operadores) pueden mover fondos internos, previa autorización del usuario.  
- **Beneficio:** Seguridad y separación de responsabilidades.

---

### 🧱 Declaraciones de tipos (`type`, `enum`, `struct`)
- **Motivo:** El contrato anterior manejaba balances sin estructura clara.  
- **Mejora:** Se introdujeron tipos personalizados para organizar los datos:
  - `type AccountId is bytes32;`
  - `enum Currency { NATIVE, USD }`
  - `struct Ledger { uint256 balance; uint40 lastUpdated; }`
- **Beneficio:** Código más legible, seguro y modular, facilitando futuras extensiones (como soporte multi-moneda).

---

### 🔗 Integración con Chainlink Price Feed
- **Motivo:** La primera versión no permitía calcular el valor real en USD.  
- **Mejora:** Se añadió una instancia de **`AggregatorV3Interface`** para consultar precios ETH/USD en tiempo real.  
- **Beneficio:** Permite mostrar el valor actualizado de los depósitos en USD y mantener coherencia con el mercado.

---

### ⚙️ Mappings anidados y función de conversión
- **Motivo:** Los balances y autorizaciones estaban limitados a un solo nivel.  
- **Mejora:** 
  - `mapping(address => mapping(Currency => Ledger))` para manejar múltiples monedas.  
  - `mapping(address => mapping(address => uint256))` para *allowances* (autorizaciones).  
  - Función `convertDecimals()` para ajustar unidades entre ETH (18), oráculo (8) y USD.  
- **Beneficio:** Escalabilidad y precisión en las operaciones contables.

---

### 🧠 Optimización mediante constantes e inmutables
- **Motivo:** La versión anterior usaba variables de almacenamiento costosas en gas.  
- **Mejora:** Se agregaron variables `constant` e `immutable`:
  - `USD_DECIMALS`, `MAX_DEPOSIT_WEI`, `VERSION`
  - `priceFeed`, `ORACLE_DECIMALS` (definidos en el constructor)
- **Beneficio:** Menor costo de gas y mayor eficiencia al ejecutar funciones repetitivas.

---

## ⚙️ 2. Instrucciones de despliegue e interacción

### 🧩 Compilación en Remix

1. Abre [Remix IDE](https://remix.ethereum.org/).
2. Carga el contrato:  
3. En **Solidity Compiler**, selecciona:
- Versión: `0.8.24` o superior.
- Activa `Enable optimization`.

---

### 🚀 Despliegue

#### Testnet Sepolia con MetaMask
1. Cambia el entorno a:
2. Asegúrate de tener ETH de prueba en Sepolia:
- Faucet: [https://faucet.chain.link/sepolia](https://faucet.chain.link/sepolia)
3. En el constructor, usa:
- `initialAdmin`: tu dirección.  
- `feedAddress`: **ETH/USD Sepolia → `0x694AA1769357215DE4FAC081bf1f309aDC325306`**
4. Haz clic en **Deploy** y confirma en MetaMask.

---

### 💬 Interacción básica

| Función | Tipo | Descripción |
|----------|------|-------------|
| `deposit()` | `external payable` | Envía ETH al contrato y actualiza tu saldo interno. |
| `withdraw(uint256 amountWei)` | `external` | Retira ETH del saldo interno. |
| `balanceOf(address user)` | `view` | Devuelve saldo en wei (ETH). |
| `balanceInUSD(address user)` | `view` | Calcula el valor actual en USD (vía Chainlink). |
| `addAdmin(address)` | `onlyAdmin` | Agrega un nuevo administrador. |
| `addTeller(address)` | `onlyAdmin` | Agrega un operador autorizado. |
| `approve(address spender, uint256 amount)` | `external` | Autoriza a otro usuario a mover tus fondos. |
| `transferFrom(address owner, address to, uint256 amount)` | `external` | Transfiere saldo interno, si fue aprobado. |

---

### 💡 Ejemplo de uso rápido en Remix

1. **Depositar ETH:**  
- En el campo “Value”, ingresa `1 ether`.  
- Ejecuta `deposit()` → tu saldo aumenta.  

2. **Consultar saldo:**  
- Llama a `balanceOf(<tu address>)` → muestra tu saldo interno.  

3. **Ver valor en USD:**  
- Llama a `balanceInUSD(<tu address>)` → valor según el oráculo.  

4. **Retirar fondos:**  
- Ejecuta `withdraw(1000000000000000000)` → (equivale a 1 ETH).  

---

## 🧩 3. Notas de diseño y *trade-offs*

### 🔒 Seguridad
- Se usa el patrón **Checks–Effects–Interactions** en `withdraw` para prevenir *reentrancy*.  
- No se incluyó `ReentrancyGuard` para mantener el gas bajo, pero puede añadirse fácilmente.  
- El oráculo Chainlink se valida en el constructor; si se usa una dirección incorrecta, la transacción revierte.  

---

### ⚙️ Diseño modular
- Los tipos personalizados (`enum`, `struct`, `type`) facilitan la extensión del contrato a más monedas o activos tokenizados.
- Los *mappings anidados* permiten llevar registros internos por usuario y moneda sin depender de ERC20 externos.

---

### 💸 Trade-offs de diseño
| Decisión | Beneficio | Costo o limitación |
|-----------|------------|--------------------|
| Uso de `immutable` y `constant` | Eficiencia en gas | Inmutables no pueden cambiar tras despliegue |
| Integración directa de Chainlink | Datos confiables en USD | Depende de disponibilidad del feed en la red |
| Control de acceso interno | Mayor seguridad | Mayor complejidad en despliegue y gestión de roles |
| Uso de `receive()` para depósitos automáticos | Comodidad | Posible ingreso accidental sin metadata |
| Conversión de decimales | Precisión en cotizaciones | Ligero aumento de gas en cálculos |

---

## 📋 Resumen general

| Elemento | Descripción |
|-----------|-------------|
| **Nombre del contrato:** | `KipuBankV2` |
| **Lenguaje:** | Solidity ^0.8.24 |
| **Oráculo:** | Chainlink ETH/USD |
| **Red recomendada:** | Sepolia Testnet |
| **Roles:** | `Admin`, `Teller` |
| **Monedas:** | ETH (nativa), USD (virtual) |
| **Lógica principal:** | Depósitos, retiros y cotización en tiempo real |
| **Autor:** | Johann Cañar Muñoz |

---

## 👨‍💻 Autor y créditos

Desarrollado por **Christian Cañar**  
Proyecto académico: *KipuBankV2 – Contrato inteligente con integración Chainlink*  
© 2025 — Todos los derechos reservados.

