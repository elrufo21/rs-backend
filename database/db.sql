-- =====================================================
-- SISTEMA DE MONITOREO DOCENTE - ESQUEMA CON SERIAL
-- PostgreSQL 15+
-- =====================================================

-- =====================================================
-- 1. TABLA: users (Usuarios del Sistema) - MEJORADA
-- =====================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'teacher' CHECK (role IN ('admin', 'coordinator', 'teacher', 'observer')),
    avatar_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    -- MEJORAS DE SEGURIDAD
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    password_changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- CAMPOS EXISTENTES
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(is_active);
CREATE INDEX idx_users_locked ON users(locked_until) WHERE locked_until IS NOT NULL;

-- =====================================================
-- 2. TABLA: schools (Instituciones Educativas)
-- =====================================================
CREATE TABLE schools (
    id SERIAL PRIMARY KEY,
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

-- Índices para schools
CREATE INDEX idx_schools_name ON schools(name);
CREATE INDEX idx_schools_code ON schools(code);

-- =====================================================
-- 3. TABLA: user_schools (Relación Usuario-Institución)
-- =====================================================
CREATE TABLE user_schools (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    school_id INTEGER NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'teacher' CHECK (role IN ('principal', 'coordinator', 'teacher', 'observer')),
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para user_schools
CREATE INDEX idx_user_schools_user_id ON user_schools(user_id);
CREATE INDEX idx_user_schools_school_id ON user_schools(school_id);
CREATE INDEX idx_user_schools_active ON user_schools(is_active);
CREATE UNIQUE INDEX idx_user_schools_unique ON user_schools(user_id, school_id) WHERE is_active = true;

-- =====================================================
-- 4. TABLA: monitoring_templates (Plantillas de Monitoreo)
-- =====================================================
CREATE TABLE monitoring_templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    title VARCHAR(500) NOT NULL,
    subtitle TEXT,
    description TEXT,
    levels JSONB NOT NULL, -- {"I": "desc", "II": "desc", "III": "desc", "IV": "desc"}
    is_active BOOLEAN DEFAULT true,
    is_public BOOLEAN DEFAULT false,
    created_by INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    usage_count INTEGER DEFAULT 0
);

-- Índices para monitoring_templates
CREATE INDEX idx_monitoring_templates_name ON monitoring_templates USING gin(to_tsvector('spanish', name));
CREATE INDEX idx_monitoring_templates_title ON monitoring_templates USING gin(to_tsvector('spanish', title));
CREATE INDEX idx_monitoring_templates_active ON monitoring_templates(is_active);
CREATE INDEX idx_monitoring_templates_created_by ON monitoring_templates(created_by);
CREATE INDEX idx_monitoring_templates_created_at ON monitoring_templates(created_at);
CREATE INDEX idx_monitoring_templates_levels ON monitoring_templates USING gin(levels);

-- =====================================================
-- 5. TABLA: performances (Desempeños)
-- =====================================================
CREATE TABLE performances (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES monitoring_templates(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    order_index INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performances
CREATE INDEX idx_performances_template_id ON performances(template_id);
CREATE INDEX idx_performances_order_index ON performances(order_index);
CREATE INDEX idx_performances_title ON performances USING gin(to_tsvector('spanish', title));

-- =====================================================
-- 6. TABLA: questions (Preguntas de Evaluación)
-- =====================================================
CREATE TABLE questions (
    id SERIAL PRIMARY KEY,
    performance_id INTEGER NOT NULL REFERENCES performances(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    order_index INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para questions
CREATE INDEX idx_questions_performance_id ON questions(performance_id);
CREATE INDEX idx_questions_order_index ON questions(order_index);
CREATE INDEX idx_questions_text ON questions USING gin(to_tsvector('spanish', text));

-- =====================================================
-- 7. TABLA: monitoring_sessions (Sesiones de Monitoreo) - MEJORADA
-- =====================================================
CREATE TABLE monitoring_sessions (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES monitoring_templates(id),
    teacher_id INTEGER NOT NULL REFERENCES users(id),
    observer_id INTEGER NOT NULL REFERENCES users(id),
    session_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    status VARCHAR(50) NOT NULL DEFAULT 'in-progress' CHECK (status IN ('in-progress', 'completed', 'cancelled')),
    notes TEXT,
    total_score DECIMAL(5,2),
    average_level DECIMAL(3,2),
    -- CAMPOS ADICIONALES MEJORADOS
    subject VARCHAR(100),
    grade_level VARCHAR(50),
    classroom VARCHAR(50),
    duration_minutes INTEGER,
    -- CAMPOS EXISTENTES
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para monitoring_sessions
CREATE INDEX idx_monitoring_sessions_template_id ON monitoring_sessions(template_id);
CREATE INDEX idx_monitoring_sessions_teacher_id ON monitoring_sessions(teacher_id);
CREATE INDEX idx_monitoring_sessions_observer_id ON monitoring_sessions(observer_id);
CREATE INDEX idx_monitoring_sessions_session_date ON monitoring_sessions(session_date);
CREATE INDEX idx_monitoring_sessions_status ON monitoring_sessions(status);
CREATE INDEX idx_monitoring_sessions_date_status ON monitoring_sessions(session_date, status);
CREATE INDEX idx_monitoring_sessions_subject ON monitoring_sessions(subject);
CREATE INDEX idx_monitoring_sessions_grade ON monitoring_sessions(grade_level);

-- =====================================================
-- 8. TABLA: monitoring_responses (Respuestas del Monitoreo)
-- =====================================================
CREATE TABLE monitoring_responses (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES monitoring_sessions(id) ON DELETE CASCADE,
    question_id INTEGER NOT NULL REFERENCES questions(id),
    selected_level VARCHAR(10) NOT NULL CHECK (selected_level IN ('I', 'II', 'III', 'IV')),
    score DECIMAL(3,2),
    comments TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para monitoring_responses
CREATE INDEX idx_monitoring_responses_session_id ON monitoring_responses(session_id);
CREATE INDEX idx_monitoring_responses_question_id ON monitoring_responses(question_id);
CREATE INDEX idx_monitoring_responses_level ON monitoring_responses(selected_level);
CREATE INDEX idx_monitoring_responses_session_level ON monitoring_responses(session_id, selected_level);
CREATE UNIQUE INDEX idx_monitoring_responses_unique ON monitoring_responses(session_id, question_id);

-- =====================================================
-- 9. TABLA: monitoring_reports (Reportes de Monitoreo)
-- =====================================================
CREATE TABLE monitoring_reports (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES monitoring_sessions(id),
    report_type VARCHAR(50) NOT NULL DEFAULT 'summary' CHECK (report_type IN ('summary', 'detailed', 'comparative')),
    content JSONB NOT NULL,
    generated_by INTEGER NOT NULL REFERENCES users(id),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    file_path VARCHAR(500),
    file_size INTEGER
);

-- Índices para monitoring_reports
CREATE INDEX idx_monitoring_reports_session_id ON monitoring_reports(session_id);
CREATE INDEX idx_monitoring_reports_type ON monitoring_reports(report_type);
CREATE INDEX idx_monitoring_reports_generated_by ON monitoring_reports(generated_by);

-- =====================================================
-- NUEVAS TABLAS MEJORADAS
-- =====================================================

-- =====================================================
-- 10. TABLA: audit_logs (Logs de Auditoría) - NUEVA
-- =====================================================
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    user_id INTEGER REFERENCES users(id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para audit_logs
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- =====================================================
-- 11. TABLA: system_config (Configuraciones del Sistema) - NUEVA
-- =====================================================
CREATE TABLE system_config (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    data_type VARCHAR(50) DEFAULT 'text' CHECK (data_type IN ('text', 'number', 'boolean', 'json')),
    updated_by INTEGER REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para system_config
CREATE INDEX idx_system_config_public ON system_config(is_public);
CREATE INDEX idx_system_config_type ON system_config(data_type);

-- =====================================================
-- 12. TABLA: notifications (Notificaciones) - NUEVA
-- =====================================================
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error')),
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    action_url VARCHAR(500),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_expires ON notifications(expires_at) WHERE expires_at IS NOT NULL;

-- =====================================================
-- 13. TABLA: attachments (Archivos Adjuntos) - NUEVA
-- =====================================================
CREATE TABLE attachments (
    id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES monitoring_sessions(id) ON DELETE CASCADE,
    question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size INTEGER NOT NULL,
    mime_type VARCHAR(100),
    original_name VARCHAR(255),
    uploaded_by INTEGER NOT NULL REFERENCES users(id),
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para attachments
CREATE INDEX idx_attachments_session_id ON attachments(session_id);
CREATE INDEX idx_attachments_question_id ON attachments(question_id);
CREATE INDEX idx_attachments_uploaded_by ON attachments(uploaded_by);
CREATE INDEX idx_attachments_mime_type ON attachments(mime_type);

-- =====================================================
-- 14. TABLA: user_sessions (Sesiones de Usuario) - NUEVA
-- =====================================================
CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para user_sessions
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_active ON user_sessions(is_active);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);

-- =====================================================
-- FUNCIONES Y TRIGGERS MEJORADOS
-- =====================================================

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Función para auditoría automática
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, record_id, action, new_values, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), current_setting('app.current_user_id', true)::INTEGER);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, old_values, new_values, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_setting('app.current_user_id', true)::INTEGER);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, old_values, user_id)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), current_setting('app.current_user_id', true)::INTEGER);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Función para calcular estadísticas de monitoreo
CREATE OR REPLACE FUNCTION get_monitoring_stats(template_id INTEGER)
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

-- Función para limpiar sesiones expiradas
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_sessions WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar notificaciones expiradas
CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS MEJORADOS
-- =====================================================

-- Triggers para actualizar timestamps
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_monitoring_templates_updated_at BEFORE UPDATE ON monitoring_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_performances_updated_at BEFORE UPDATE ON performances FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_questions_updated_at BEFORE UPDATE ON questions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_monitoring_sessions_updated_at BEFORE UPDATE ON monitoring_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_schools_updated_at BEFORE UPDATE ON schools FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_schools_updated_at BEFORE UPDATE ON user_schools FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Triggers para auditoría (solo en tablas críticas)
CREATE TRIGGER audit_users_trigger AFTER INSERT OR UPDATE OR DELETE ON users FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
CREATE TRIGGER audit_monitoring_sessions_trigger AFTER INSERT OR UPDATE OR DELETE ON monitoring_sessions FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
CREATE TRIGGER audit_monitoring_responses_trigger AFTER INSERT OR UPDATE OR DELETE ON monitoring_responses FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- =====================================================
-- VISTAS MEJORADAS
-- =====================================================

-- Vista: monitoring_summary
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

-- Vista: teacher_performance_summary
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

-- Vista: user_activity_summary
CREATE VIEW user_activity_summary AS
SELECT 
    u.id as user_id,
    u.first_name || ' ' || u.last_name as user_name,
    u.role,
    u.last_login,
    COUNT(DISTINCT us.id) as active_schools,
    COUNT(DISTINCT ms.id) as total_sessions,
    COUNT(DISTINCT n.id) as unread_notifications
FROM users u
LEFT JOIN user_schools us ON u.id = us.user_id AND us.is_active = true
LEFT JOIN monitoring_sessions ms ON u.id = ms.teacher_id OR u.id = ms.observer_id
LEFT JOIN notifications n ON u.id = n.user_id AND n.is_read = false
WHERE u.is_active = true
GROUP BY u.id, u.first_name, u.last_name, u.role, u.last_login;

-- =====================================================
-- DATOS DE EJEMPLO MEJORADOS
-- =====================================================

-- Insertar usuario administrador por defecto
INSERT INTO users (email, password_hash, first_name, last_name, role) VALUES
('admin@r2.edu', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Administrador', 'Sistema', 'admin');

-- Insertar escuela de ejemplo
INSERT INTO schools (name, code, address, phone, email) VALUES
('Escuela de Ejemplo', 'EE001', 'Dirección de ejemplo', '+1234567890', 'info@escuela.edu');

-- Insertar configuraciones del sistema
INSERT INTO system_config (key, value, description, is_public, data_type) VALUES
('max_login_attempts', '5', 'Número máximo de intentos de login fallidos', false, 'number'),
('session_timeout_minutes', '480', 'Tiempo de expiración de sesión en minutos', false, 'number'),
('notification_retention_days', '30', 'Días de retención de notificaciones', false, 'number'),
('file_upload_max_size_mb', '10', 'Tamaño máximo de archivo en MB', true, 'number'),
('system_maintenance_mode', 'false', 'Modo mantenimiento del sistema', true, 'boolean');

-- Insertar plantilla de monitoreo básica
INSERT INTO monitoring_templates (name, title, levels, created_by) VALUES
(
    'Monitoreo Docente Básico',
    'Evaluación del Desempeño Docente en el Aula',
    '{
        "I": "No alcanza los estándares mínimos del desempeño docente",
        "II": "Muestra progreso pero con deficencias evidentes",
        "III": "Cumple con los estándares esperados de calidad",
        "IV": "Excede los estándares y muestra excelencia"
    }',
    1
);

-- Insertar desempeños de ejemplo
INSERT INTO performances (template_id, title, description, order_index) VALUES
(
    1,
    'Involucra activamente a los estudiantes en el proceso de aprendizaje',
    'Promueve el interés y participación de los estudiantes',
    1
),
(
    1,
    'Utiliza estrategias pedagógicas efectivas',
    'Aplica metodologías apropiadas para el aprendizaje',
    2
);

-- Insertar preguntas de ejemplo
INSERT INTO questions (performance_id, text, order_index) VALUES
(
    1,
    '¿El docente promueve la participación activa de los estudiantes?',
    1
),
(
    2,
    '¿Las estrategias utilizadas son apropiadas para el contenido?',
    1
);

-- =====================================================
-- ÍNDICES ADICIONALES PARA PERFORMANCE
-- =====================================================

-- Para búsquedas rápidas
CREATE INDEX idx_monitoring_templates_search ON monitoring_templates 
USING gin(to_tsvector('spanish', name || ' ' || COALESCE(title, '')));

-- Para ordenamiento por fecha
CREATE INDEX idx_monitoring_templates_created_at_desc ON monitoring_templates(created_at DESC);

-- Para usuarios por institución y rol
CREATE INDEX idx_user_schools_school_role ON user_schools(school_id, role, is_active);

-- Para auditoría por fecha
CREATE INDEX idx_audit_logs_date_range ON audit_logs(created_at DESC);

-- Para notificaciones por usuario y estado
CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read, created_at DESC);

-- Para archivos por tipo y sesión
CREATE INDEX idx_attachments_session_type ON attachments(session_id, mime_type);

-- =====================================================
-- COMENTARIOS FINALES MEJORADOS
-- =====================================================

COMMENT ON TABLE users IS 'Tabla de usuarios del sistema (admin, coordinadores, docentes, observadores) con mejoras de seguridad';
COMMENT ON TABLE schools IS 'Instituciones educativas donde se realizan los monitoreos';
COMMENT ON TABLE monitoring_templates IS 'Plantillas de evaluación para diferentes tipos de monitoreo';
COMMENT ON TABLE performances IS 'Criterios de desempeño dentro de cada plantilla';
COMMENT ON TABLE questions IS 'Preguntas específicas para evaluar cada criterio de desempeño';
COMMENT ON TABLE monitoring_sessions IS 'Sesiones individuales de monitoreo docente con metadatos mejorados';
COMMENT ON TABLE monitoring_responses IS 'Respuestas específicas de cada sesión de monitoreo';
COMMENT ON TABLE monitoring_reports IS 'Reportes generados a partir de las sesiones de monitoreo';
COMMENT ON TABLE audit_logs IS 'Logs de auditoría para todas las operaciones críticas del sistema';
COMMENT ON TABLE system_config IS 'Configuraciones del sistema centralizadas y configurables';
COMMENT ON TABLE notifications IS 'Sistema de notificaciones para usuarios del sistema';
COMMENT ON TABLE attachments IS 'Archivos adjuntos para sesiones y preguntas de monitoreo';
COMMENT ON TABLE user_sessions IS 'Sesiones activas de usuario para control de autenticación';

-- =====================================================
-- FIN DEL ESQUEMA CON SERIAL
-- =====================================================