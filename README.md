# 🎬 AnimaCine — Catálogo de Películas Animadas

Sistema web para la gestión de un catálogo de películas animadas. Permite a los usuarios consultar películas, calificarlas y guardar sus favoritas. Incluye panel de administrador para gestionar el catálogo.

## 📁 Estructura del proyecto

```
animacine/
├── frontend/
│   ├── catalogo-animadas.html   ← Vista pública del catálogo
│   └── admin.html               ← Panel de administrador
├── backend/
│   ├── package.json
│   ├── .env.example             ← Copiar a .env y configurar
│   └── src/
│       ├── server.js            ← Entrada principal
│       ├── db.js                ← Conexión SQL Server
│       ├── middleware/
│       │   └── auth.js          ← JWT + roles
│       └── routes/
│           ├── auth.js          ← Registro y login
│           └── peliculas.js     ← CRUD catálogo
├── database/
│   └── schema.sql               ← Script base de datos
└── README.md
```

## 🚀 Instalación

### 1. Base de datos
Ejecuta `database/schema.sql` en SQL Server Management Studio.

### 2. Backend
```bash
cd backend
npm install
cp .env.example .env
# Editar .env con tus credenciales de SQL Server
npm run dev
```

### 3. Frontend
Abre `frontend/catalogo-animadas.html` en tu navegador.
El panel admin está en `frontend/admin.html`.

## 🔌 Endpoints de la API

| Método | Ruta | Auth |
|--------|------|------|
| POST | `/api/auth/registro` | — |
| POST | `/api/auth/login` | — |
| GET | `/api/peliculas` | — |
| GET | `/api/peliculas/:id` | — |
| POST | `/api/peliculas/:id/calificar` | 🔐 Usuario |
| POST | `/api/peliculas/:id/favorito` | 🔐 Usuario |
| GET | `/api/peliculas/usuario/favoritos` | 🔐 Usuario |
| POST | `/api/peliculas` | 🔐 Admin |
| PUT | `/api/peliculas/:id` | 🔐 Admin |
| DELETE | `/api/peliculas/:id` | 🔐 Admin |

## 🛠️ Tecnologías

- **Frontend**: HTML, CSS, JavaScript puro
- **Backend**: Node.js + Express
- **Base de datos**: SQL Server Express
- **Auth**: JWT + bcryptjs

## 👤 Usuario administrador por defecto

```
Email: admin@animacine.com
Password: (configurar al ejecutar schema.sql)
```
