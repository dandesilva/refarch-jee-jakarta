# Customer Order Services - Jakarta EE 10 Edition

> **📌 Java 11 LTS Version** | Looking for [Java 21 (Recommended)](../../tree/java-21)? | [Compare Versions](VERSION_MATRIX.md)

A modernized enterprise Java application demonstrating Jakarta EE 10 features, running on WildFly 31 with PostgreSQL.

## 📋 Overview

This project is a **migrated and modernized version** of [IBM's reference architecture for JEE Customer Order Services](https://github.com/ibm-cloud-architecture/refarch-jee-customerorder).
The application has been upgraded from legacy JavaEE 5/6 to **Jakarta EE 10**, enabling it to run on modern application servers and cloud-native infrastructure.

### What This Application Does

Customer Order Services is a full-stack enterprise application that provides:
- **Product Catalog Management** - Browse products organized by categories
- **Shopping Cart** - Add/remove items, manage quantities
- **Order Management** - Submit and track customer orders
- **Customer Profiles** - Business and residential customer types
- **RESTful API** - JSON-based web services for all operations

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Language** | Java | 11 |
| **Enterprise Platform** | Jakarta EE | 10 |
| **Application Server** | WildFly | 31.0.1.Final |
| **Database** | PostgreSQL | 15 |
| **ORM/JPA** | Hibernate | 6.4.4.Final |
| **Build Tool** | Maven | 3.x |
| **Container Runtime** | Podman/Docker | Latest |

## 🎯 Key Features

### Enterprise Patterns Demonstrated

- **Jakarta Persistence (JPA 3.0)** - Entity mapping, relationships, named queries
- **Enterprise JavaBeans (EJB 4.0)** - Stateless session beans, transaction management
- **JAX-RS (RESTful Web Services 3.1)** - REST endpoints with JSON serialization
- **CDI (Contexts & Dependency Injection 4.0)** - Dependency injection, scopes
- **JSON-B (Jakarta JSON Binding)** - Automatic JSON mapping
- **JTA (Transactions)** - Declarative transaction management

### Architecture Highlights

```
┌─────────────────────────────────────────────────────┐
│            REST API Layer (JAX-RS)                  │
│  /Product  /Category  /Customer  /Order             │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│         Business Logic Layer (EJB)                  │
│  ProductSearchService  CustomerOrderServices        │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│        Data Access Layer (JPA/Hibernate)            │
│  Product  Category  Customer  Order  LineItem       │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│              PostgreSQL Database                     │
└─────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **Java 11 or later**
- **Maven 3.6+**
- **Podman** or Docker
- **Git**

### 1. Clone the Repository

```bash
git clone https://github.com/dandesilva/refarch-jee-jakarta.git
cd refarch-jee-jakarta
```

### 2. Start the Database

```bash
# Create network
podman network create customerorder-net

# Start PostgreSQL
podman run -d --name postgres-orderdb \
  --network customerorder-net \
  -p 15432:5432 \
  -e POSTGRES_DB=ORDERDB \
  -e POSTGRES_USER=db2inst1 \
  -e POSTGRES_PASSWORD=db2inst1 \
  postgres:15

# Load schema and sample data
podman exec -i postgres-orderdb \
  psql -U db2inst1 -d ORDERDB < Common/createOrderDB_postgres.sql
```

### 3. Build and Run the Application

```bash
# Build the container
podman build -f Dockerfile.redhat -t customerorder-app:latest .

# Run the application
podman run -d --name customerorder-app \
  --network customerorder-net \
  -p 8080:8080 \
  -p 9990:9990 \
  customerorder-app:latest
```

### 4. Access the Application

**REST API Base URL:** http://localhost:8080/CustomerOrderServicesWeb/jaxrs

**Test Endpoints:**
```bash
# Get product by ID
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1

# List all categories
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category

# Get products by category
curl 'http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product?categoryId=1'
```

**WildFly Admin Console:** http://localhost:9990

## 📁 Project Structure

```
refarch-jee-jakarta/
├── CustomerOrderServicesProject/    # Parent POM (multi-module coordinator)
├── CustomerOrderServices/           # EJB module (business logic, entities)
│   ├── ejbModule/
│   │   ├── org/pwte/example/domain/         # JPA entities
│   │   ├── org/pwte/example/service/        # EJB services
│   │   └── org/pwte/example/exception/      # Business exceptions
│   └── pom.xml
├── CustomerOrderServicesWeb/        # WAR module (REST API)
│   ├── src/org/pwte/example/resources/      # JAX-RS resources
│   ├── WebContent/                          # Static content
│   └── pom.xml
├── CustomerOrderServicesApp/        # EAR assembly
│   └── pom.xml
├── Common/                          # Database scripts, config
│   └── createOrderDB_postgres.sql
├── Dockerfile.redhat               # Production container build
├── MIGRATION.md                    # Detailed migration guide
├── DEPLOYMENT.md                   # Deployment instructions
└── README.md                       # This file
```

## 🔌 REST API Reference

### Products

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/Product/{id}` | Get product by ID |
| GET | `/Product?categoryId={id}` | List products by category |

### Categories

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/Category/{id}` | Get category with subcategories |
| GET | `/Category` | List top-level categories |

### Customer Operations (Require Authentication)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/Customer` | Get customer info with open order |
| PUT | `/Customer/Address` | Update customer address |
| POST | `/Customer/OpenOrder/LineItem` | Add item to cart |
| DELETE | `/Customer/OpenOrder/LineItem/{id}` | Remove item from cart |
| POST | `/Customer/OpenOrder` | Submit order |
| GET | `/Customer/Orders` | Get order history |

## 📊 Sample Data

The database includes pre-loaded sample data:

**13 Products:**
- Movies: Star Wars DVDs (Return of the Jedi, Empire Strikes Back, New Hope)
- Music: CDs from various artists
- Gaming: PlayStation 3, Nintendo Wii, XBOX 360
- Electronics: DVD Players, TVs, Cellphones

**8 Categories:**
- Entertainment (Movies, Music, Games)
- Electronics (TV, Cellphones, DVD Players)

## 🛠️ Development

### Build Locally

```bash
cd CustomerOrderServicesProject
mvn clean package
```

The build produces:
- `CustomerOrderServices/target/CustomerOrderServices-0.1.0-SNAPSHOT.jar` (EJB)
- `CustomerOrderServicesWeb/target/CustomerOrderServicesWeb-0.1.0-SNAPSHOT.war` (WAR)
- `CustomerOrderServicesApp/target/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear` (EAR)

### Deploy to Existing WildFly

```bash
cp CustomerOrderServicesApp/target/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear \
   $WILDFLY_HOME/standalone/deployments/
```

**Note:** You must configure the PostgreSQL datasource first. See [DEPLOYMENT.md](DEPLOYMENT.md) for details.

### Run Tests

```bash
mvn test
```

**Note:** Test module currently excluded from build during migration. See [MIGRATION.md](MIGRATION.md) for details.

## 📖 Documentation

- **[MIGRATION.md](MIGRATION.md)** - Complete migration guide from JavaEE to Jakarta EE
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed deployment instructions for various environments
- **[docs/session-logs/](docs/session-logs/)** - Step-by-step migration session logs

## 🔄 Migration from JavaEE

This application was migrated from JavaEE 5/6 to Jakarta EE 10. Key changes:

### Package Renames
- `javax.persistence.*` → `jakarta.persistence.*`
- `javax.ejb.*` → `jakarta.ejb.*`
- `javax.ws.rs.*` → `jakarta.ws.rs.*`
- `javax.enterprise.context.*` → `jakarta.enterprise.context.*`

### Dependency Updates
- JavaEE API 6.0 → Jakarta EE API 10.0
- Java 1.6 → Java 11
- Apache OpenJPA → Hibernate 6.4.4
- IBM WebSphere Liberty → WildFly 31
- IBM DB2 → PostgreSQL 15
- Jackson Codehaus → Jackson FasterXML
- IBM JSON library → org.json

### Architecture Improvements
- Replaced JNDI lookups with `@EJB` injection
- Added `@RequestScoped` for proper CDI scoping
- Migrated to JSON-B for JSON serialization
- Modernized build system and containerization

See [MIGRATION.md](MIGRATION.md) for complete details.

## 🐳 Container Details

### Multi-Stage Build

The `Dockerfile.redhat` uses a two-stage build:

1. **Builder Stage** - Red Hat UBI 9 with OpenJDK 17 and Maven
2. **Runtime Stage** - WildFly 31 with PostgreSQL JDBC driver

### Included Configuration

- PostgreSQL JDBC driver (42.7.1) installed as WildFly module
- Datasource configured via CLI: `java:/jdbc/orderds`
- Connection pool settings optimized for production
- Proper file permissions for jboss user

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| DB_HOST | postgres-orderdb | Database hostname |
| DB_PORT | 5432 | Database port |
| DB_NAME | ORDERDB | Database name |
| DB_USER | db2inst1 | Database username |
| DB_PASSWORD | db2inst1 | Database password |

## 🔒 Security Notes

**⚠️ Important:** This application is configured with `@PermitAll` on EJB services for demonstration purposes. 

For production deployment:
- Enable authentication (LDAP, Database, etc.)
- Replace `@PermitAll` with `@RolesAllowed` annotations
- Configure security domains in WildFly
- Enable HTTPS/TLS
- Secure management interfaces

See the original IBM repository for LDAP integration examples.

## 🧪 Testing

### Manual API Testing

```bash
# Test product endpoint
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1 | jq

# Test categories
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category | jq

# Test product search
curl 'http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product?categoryId=2' | jq
```

### Database Verification

```bash
# Connect to database
podman exec -it postgres-orderdb psql -U db2inst1 -d ORDERDB

# Query products
SELECT product_id, name, price FROM product;

# Query categories
SELECT cat_id, cat_name, parent_cat FROM category;
```

## 🤝 Contributing

This is a reference architecture demonstration. For production use cases:

1. Enable and update the test module (`CustomerOrderServicesTest`)
2. Add integration tests
3. Implement proper security
4. Configure production-grade logging
5. Set up monitoring and health checks
6. Add API documentation (OpenAPI/Swagger)

## 📝 License

This project maintains the original Apache 2.0 license from the IBM reference architecture.

## 🙏 Acknowledgments

- **Original Project:** IBM Cloud Architecture - [refarch-jee-customerorder](https://github.com/ibm-cloud-architecture/refarch-jee-customerorder)
- **Migration Team:** Dan DeSilva
- **Date:** April 2026

## 📞 Support

For issues or questions:
- Review the [MIGRATION.md](MIGRATION.md) guide
- Check the [session logs](docs/session-logs/) for detailed troubleshooting
- Open an issue on GitHub

## 🎓 Learning Resources

This application demonstrates:
- **Enterprise patterns** from the Jakarta EE specification
- **Cloud-native deployment** using containers
- **Database migration** from DB2 to PostgreSQL
- **Legacy modernization** best practices
- **Multi-module Maven** project structure

Perfect for:
- Learning Jakarta EE 10
- Understanding enterprise Java architecture
- Practicing legacy application migration
- Containerization examples

---

**Status:** ✅ Production-ready for demonstration purposes  
**Last Updated:** April 3, 2026  
**Jakarta EE Version:** 10  
**Java Version:** 11 (compatible with 17+)
