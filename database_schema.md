# Base de Datos - Sistema de Monitoreo Docente

## 🗄️ **Configuración Recomendada**

- **Sistema**: PostgreSQL 15+
- **Encoding**: UTF-8
- **Collation**: utf8_unicode_ci
- **Timezone**: UTC

## 📊 **Esquema de Base de Datos**

### **1. Tabla: users (Usuarios del Sistema)**

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'teacher' CHECK (role IN ('admin', 'coordinator', 'teacher', 'observer')),
    avatar_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(is_active);
```

### **2. Tabla: monitoring_templates (Plantillas de Monitoreo)**

```sql
CREATE TABLE monitoring_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    title VARCHAR(500) NOT NULL,
    subtitle TEXT,
    description TEXT,
    levels JSONB NOT NULL, -- {"I": "desc", "II": "desc", "III": "desc", "IV": "desc"}
    is_active BOOLEAN DEFAULT true,
    is_public BOOLEAN DEFAULT false,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    usage_count INTEGER DEFAULT 0
);

-- Índices
CREATE INDEX idx_monitoring_templates_name ON monitoring_templates USING gin(to_tsvector('spanish', name));
CREATE INDEX idx_monitoring_templates_title ON monitoring_templates USING gin(to_tsvector('spanish', title));
CREATE INDEX idx_monitoring_templates_active ON monitoring_templates(is_active);
CREATE INDEX idx_monitoring_templates_created_by ON monitoring_templates(created_by);
CREATE INDEX idx_monitoring_templates_created_at ON monitoring_templates(created_at);
CREATE INDEX idx_monitoring_templates_levels ON monitoring_templates USING gin(levels);
```

### **3. Tabla: performances (Desempeños)**

```sql
CREATE TABLE performances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES monitoring_templates(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    order_index INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_performances_template_id ON performances(template_id);
CREATE INDEX idx_performances_order_index ON performances(order_index);
CREATE INDEX idx_performances_title ON performances USING gin(to_tsvector('spanish', title));
```

### **4. Tabla: questions (Preguntas de Evaluación)**

```sql
CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    performance_id UUID NOT NULL REFERENCES performances(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    order_index INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_questions_performance_id ON questions(performance_id);
CREATE INDEX idx_questions_order_index ON questions(order_index);
CREATE INDEX idx_questions_text ON questions USING gin(to_tsvector('spanish', text));
```

### **5. Tabla: monitoring_sessions (Sesiones de Monitoreo)**

```sql
CREATE TABLE monitoring_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES monitoring_templates(id),
    teacher_id UUID NOT NULL REFERENCES users(id),
    observer_id UUID NOT NULL REFERENCES users(id),
    session_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    status VARCHAR(50) NOT NULL DEFAULT 'in-progress' CHECK (status IN ('in-progress', 'completed', 'cancelled')),
    notes TEXT,
    total_score DECIMAL(5,2),
    average_level DECIMAL(3,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_monitoring_sessions_template_id ON monitoring_sessions(template_id);
CREATE INDEX idx_monitoring_sessions_teacher_id ON monitoring_sessions(teacher_id);
CREATE INDEX idx_monitoring_sessions_observer_id ON monitoring_sessions(observer_id);
CREATE INDEX idx_monitoring_sessions_session_date ON monitoring_sessions(session_date);
CREATE INDEX idx_monitoring_sessions_status ON monitoring_sessions(status);
```

### **6. Tabla: monitoring_responses (Respuestas del Monitoreo)**

```sql
CREATE TABLE monitoring_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES monitoring_sessions(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id),
    selected_level VARCHAR(10) NOT NULL CHECK (selected_level IN ('I', 'II', 'III', 'IV')),
    score DECIMAL(3,2),
    comments TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_monitoring_responses_session_id ON monitoring_responses(session_id);
CREATE INDEX idx_monitoring_responses_question_id ON monitoring_responses(question_id);
CREATE INDEX idx_monitoring_responses_level ON monitoring_responses(selected_level);
CREATE UNIQUE INDEX idx_monitoring_responses_unique ON monitoring_responses(session_id, question_id);
```

### **7. Tabla: schools (Instituciones Educativas)**

```sql
CREATE TABLE schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE,
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(255),
    website VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_schools_name ON schools(name);
CREATE INDEX idx_schools_code ON schools(code);
```

### **8. Tabla: user_schools (Relación Usuario-Institución)**

```sql
CREATE TABLE user_schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'teacher' CHECK (role IN ('principal', 'coordinator', 'teacher', 'observer')),
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_user_schools_user_id ON user_schools(user_id);
CREATE INDEX idx_user_schools_school_id ON user_schools(school_id);
CREATE INDEX idx_user_schools_active ON user_schools(is_active);
CREATE UNIQUE INDEX idx_user_schools_unique ON user_schools(user_id, school_id) WHERE is_active = true;
```

### **9. Tabla: monitoring_reports (Reportes de Monitoreo)**

```sql
CREATE TABLE monitoring_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES monitoring_sessions(id),
    report_type VARCHAR(50) NOT NULL DEFAULT 'summary' CHECK (report_type IN ('summary', 'detailed', 'comparative')),
    content JSONB NOT NULL,
    generated_by UUID NOT NULL REFERENCES users(id),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    file_path VARCHAR(500),
    file_size INTEGER
);

-- Índices
CREATE INDEX idx_monitoring_reports_session_id ON monitoring_reports(session_id);
CREATE INDEX idx_monitoring_reports_type ON monitoring_reports(report_type);
CREATE INDEX idx_monitoring_reports_generated_by ON monitoring_reports(generated_by);
```

## 🔧 **Funciones y Triggers**

### **Función para actualizar timestamp**

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';
```

### **Triggers para actualizar timestamps**

```sql
-- Aplicar a todas las tablas que tienen updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_monitoring_templates_updated_at BEFORE UPDATE ON monitoring_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_performances_updated_at BEFORE UPDATE ON performances FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_questions_updated_at BEFORE UPDATE ON questions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_monitoring_sessions_updated_at BEFORE UPDATE ON monitoring_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_schools_updated_at BEFORE UPDATE ON schools FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_schools_updated_at BEFORE UPDATE ON user_schools FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### **Función para calcular estadísticas de monitoreo**

```sql
CREATE OR REPLACE FUNCTION get_monitoring_stats(template_id UUID)
RETURNS TABLE (
    total_sessions BIGINT,
    completed_sessions BIGINT,
    average_score DECIMAL(5,2),
    level_distribution JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_sessions,
        COUNT(CASE WHEN ms.status = 'completed' THEN 1 END)::BIGINT as completed_sessions,
        AVG(ms.total_score) as average_score,
        jsonb_object_agg(
            mr.selected_level, 
            COUNT(*)::INTEGER
        ) as level_distribution
    FROM monitoring_sessions ms
    LEFT JOIN monitoring_responses mr ON ms.id = mr.session_id
    WHERE ms.template_id = $1
    GROUP BY ms.template_id;
END;
$$ LANGUAGE plpgsql;
```

## 📊 **Vistas Útiles**

### **Vista: monitoring_summary**

```sql
CREATE VIEW monitoring_summary AS
SELECT 
    mt.id as template_id,
    mt.name as template_name,
    mt.title as template_title,
    COUNT(DISTINCT ms.id) as total_sessions,
    COUNT(DISTINCT ms.teacher_id) as unique_teachers,
    AVG(ms.total_score) as average_score,
    AVG(ms.average_level) as average_level,
    mt.usage_count,
    mt.created_at,
    u.first_name || ' ' || u.last_name as created_by_name
FROM monitoring_templates mt
LEFT JOIN monitoring_sessions ms ON mt.id = ms.template_id
LEFT JOIN users u ON mt.created_by = u.id
WHERE mt.is_active = true
GROUP BY mt.id, mt.name, mt.title, mt.usage_count, mt.created_at, u.first_name, u.last_name;
```

### **Vista: teacher_performance_summary**

```sql
CREATE VIEW teacher_performance_summary AS
SELECT 
    u.id as teacher_id,
    u.first_name || ' ' || u.last_name as teacher_name,
    COUNT(DISTINCT ms.id) as total_monitorings,
    AVG(ms.total_score) as average_score,
    AVG(ms.average_level) as average_level,
    COUNT(DISTINCT ms.template_id) as templates_used,
    MAX(ms.session_date) as last_monitoring_date
FROM users u
LEFT JOIN monitoring_sessions ms ON u.id = ms.teacher_id
WHERE u.role = 'teacher' AND u.is_active = true
GROUP BY u.id, u.first_name, u.last_name;
```

## 🔐 **Políticas de Seguridad (RLS)**

### **Habilitar RLS en tablas sensibles**

```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitoring_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitoring_responses ENABLE ROW LEVEL SECURITY;
```

### **Política para usuarios (solo ver su propia información)**

```sql
CREATE POLICY users_own_data ON users
    FOR ALL USING (auth.uid() = id);
```

### **Política para sesiones de monitoreo**

```sql
CREATE POLICY monitoring_sessions_access ON monitoring_sessions
    FOR ALL USING (
        auth.uid() = teacher_id OR 
        auth.uid() = observer_id OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('admin', 'coordinator')
        )
    );
```

## 📈 **Índices de Performance**

### **Índices compuestos para consultas frecuentes**

```sql
-- Para búsquedas de monitoreos por fecha y estado
CREATE INDEX idx_monitoring_sessions_date_status ON monitoring_sessions(session_date, status);

-- Para respuestas por sesión y nivel
CREATE INDEX idx_monitoring_responses_session_level ON monitoring_responses(session_id, selected_level);

-- Para usuarios por institución y rol
CREATE INDEX idx_user_schools_school_role ON user_schools(school_id, role, is_active);
```

## 🚀 **Scripts de Inicialización**

### **Datos de ejemplo para niveles de desempeño**

```sql
INSERT INTO monitoring_templates (name, title, levels, created_by) VALUES
(
    'Monitoreo Docente Básico',
    'Evaluación del Desempeño Docente en el Aula',
    '{
        "I": "No alcanza los estándares mínimos del desempeño docente",
        "II": "Muestra progreso pero con deficiencias evidentes",
        "III": "Cumple con los estándares esperados de calidad",
        "IV": "Excede los estándares y muestra excelencia"
    }',
    (SELECT id FROM users WHERE role = 'admin' LIMIT 1)
);
```

### **Desempeños de ejemplo**

```sql
INSERT INTO performances (template_id, title, description, order_index) VALUES
(
    (SELECT id FROM monitoring_templates WHERE name = 'Monitoreo Docente Básico'),
    'Involucra activamente a los estudiantes en el proceso de aprendizaje',
    'Promueve el interés y participación de los estudiantes',
    1
);
```

## 📋 **Comandos de Mantenimiento**

### **Vacuum y análisis**

```sql
-- Ejecutar semanalmente
VACUUM ANALYZE;

-- Para tablas específicas
VACUUM ANALYZE monitoring_responses;
VACUUM ANALYZE monitoring_sessions;
```

### **Backup**

```bash
# Backup completo
pg_dump -h localhost -U username -d monitoring_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup solo esquema
pg_dump -h localhost -U username -d monitoring_db --schema-only > schema_backup.sql
```

## 🔍 **Consultas de Ejemplo**

### **Obtener estadísticas de un docente**

```sql
SELECT 
    u.first_name || ' ' || u.last_name as teacher_name,
    COUNT(ms.id) as total_monitorings,
    AVG(ms.total_score) as average_score,
    jsonb_object_agg(mr.selected_level, COUNT(*)) as level_distribution
FROM users u
LEFT JOIN monitoring_sessions ms ON u.id = ms.teacher_id
LEFT JOIN monitoring_responses mr ON ms.id = mr.session_id
WHERE u.id = $1 AND ms.status = 'completed'
GROUP BY u.id, u.first_name, u.last_name;
```

### **Búsqueda de monitoreos por texto**

```sql
SELECT 
    mt.name,
    mt.title,
    mt.description,
    ts_rank(to_tsvector('spanish', mt.name || ' ' || mt.title), plainto_tsquery('spanish', $1)) as rank
FROM monitoring_templates mt
WHERE to_tsvector('spanish', mt.name || ' ' || mt.title) @@ plainto_tsquery('spanish', $1)
ORDER BY rank DESC;
```

## 📱 **Consideraciones para Aplicación Móvil**

### **Optimizaciones de consulta**

```sql
-- Para listas paginadas
SELECT * FROM monitoring_templates 
WHERE is_active = true 
ORDER BY created_at DESC 
LIMIT 20 OFFSET 0;

-- Para búsquedas con debounce
SELECT id, name, title FROM monitoring_templates 
WHERE name ILIKE $1 || '%' 
LIMIT 10;
```

### **Índices para consultas móviles**

```sql
-- Para búsquedas rápidas
CREATE INDEX idx_monitoring_templates_search ON monitoring_templates 
USING gin(to_tsvector('spanish', name || ' ' || COALESCE(title, '')));

-- Para ordenamiento por fecha
CREATE INDEX idx_monitoring_templates_created_at_desc ON monitoring_templates(created_at DESC);
```

## 🔧 **Configuración del Servidor**

### **postgresql.conf optimizado**

```ini
# Memoria
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB

# Conexiones
max_connections = 100

# Logging
log_statement = 'all'
log_min_duration_statement = 1000

# Performance
random_page_cost = 1.1
effective_io_concurrency = 200
```

Esta estructura de base de datos está optimizada para PostgreSQL y proporciona una base sólida para tu sistema de monitoreo docente con excelente performance y escalabilidad.
