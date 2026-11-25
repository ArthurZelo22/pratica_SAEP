-- ( Tabelas ) 

CREATE TABLE jogadores (
    id_jogador SERIAL PRIMARY KEY,
    nickname VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha VARCHAR(100) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE modalidades (
    id_modalidade SERIAL PRIMARY KEY,
    nome VARCHAR(60) NOT NULL UNIQUE,
    descricao VARCHAR(200) NOT NULL
);

CREATE TABLE partidas (
    id_partida SERIAL PRIMARY KEY,
    id_jogador INT NOT NULL,
    id_modalidade INT NOT NULL,
    titulo VARCHAR(100) NOT NULL,
    data_partida TIMESTAMP NOT NULL,
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'Agendada',
    
    CONSTRAINT fk_partida_jogador FOREIGN KEY (id_jogador) REFERENCES jogadores(id_jogador),
    CONSTRAINT fk_partida_modalidade FOREIGN KEY (id_modalidade) REFERENCES modalidades(id_modalidade),
    CONSTRAINT chk_status_partida CHECK (status IN ('Agendada', 'Em Andamento', 'Finalizada', 'Cancelada'))
);

CREATE TABLE historico_partidas (
    id_historico SERIAL PRIMARY KEY,
    id_partida INT NOT NULL,
    acao_log VARCHAR(255) NOT NULL,
    data_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_historico_partida FOREIGN KEY (id_partida) REFERENCES partidas(id_partida) ON DELETE CASCADE
);

-- ( Triggers )

CREATE OR REPLACE FUNCTION fn_validar_partida()
RETURNS TRIGGER AS $$
DECLARE
    v_jogador_ativo BOOLEAN;
BEGIN
    SELECT ativo INTO v_jogador_ativo
    FROM jogadores
    WHERE id_jogador = NEW.id_jogador;

    IF v_jogador_ativo IS NULL THEN
        RAISE EXCEPTION 'Erro: Jogador ID % não encontrado.', NEW.id_jogador;
    ELSIF v_jogador_ativo = FALSE THEN
        RAISE EXCEPTION 'Operação bloqueada: O jogador está inativo ou banido e não pode ser vinculado a partidas.';
    END IF;

    NEW.data_criacao := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_partida
BEFORE INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_partida();

CREATE OR REPLACE FUNCTION fn_registrar_log_partida()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO historico_partidas (id_partida, acao_log, data_registro)
    VALUES (
        NEW.id_partida,
        'Partida "' || NEW.titulo || '" criada e agendada com status: ' || NEW.status,
        CURRENT_TIMESTAMP
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_historico_partida
AFTER INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_log_partida();

-- ( Valores )

INSERT INTO jogadores (nickname, email, senha, ativo) VALUES
('FallenBR', 'fallen@esports.com', 'senha123', TRUE),
('AspasKing', 'aspas@esports.com', 'valorant2026', TRUE),
('GaulesTV', 'gaules@esports.com', 'tribo999', TRUE),
('ToxicPlayer', 'toxic@esports.com', 'banido123', FALSE);

INSERT INTO modalidades (nome, descricao) VALUES
('Counter-Strike 2', 'FPS Tático 5v5 competitivo'),
('Valorant', 'FPS Tático com habilidades de agentes'),
('League of Legends', 'MOBA 5v5 em Summoners Rift');

INSERT INTO partidas (id_jogador, id_modalidade, titulo, data_partida, status) VALUES
(1, 1, 'Final Major - MIBR vs Furia', CURRENT_TIMESTAMP + INTERVAL '5 days', 'Agendada'),
(2, 2, 'Semifinal Masters - LOUD vs Sentinels', CURRENT_TIMESTAMP + INTERVAL '2 days', 'Agendada'),
(3, 3, 'Showmatch Beneficente - CBLOL Stars', CURRENT_TIMESTAMP + INTERVAL '10 days', 'Agendada');


-- ( VIEWS )

CREATE OR REPLACE VIEW vw_painel_principal AS
SELECT 
    j.nickname AS nickname_jogador,
    p.titulo AS titulo_partida,
    m.nome AS modalidade,
    p.data_partida,
    p.status AS status_disputa
FROM partidas p
INNER JOIN jogadores j ON p.id_jogador = j.id_jogador
INNER JOIN modalidades m ON p.id_modalidade = m.id_modalidade;

CREATE OR REPLACE VIEW vw_cronograma_partidas AS
SELECT 
    p.titulo AS titulo_partida,
    p.data_partida AS data_agendamento,
    p.status AS status_partida,
    EXTRACT(DAY FROM (p.data_partida - CURRENT_TIMESTAMP))::INT AS dias_restantes,
    j.nickname AS jogador_responsavel
FROM partidas p
INNER JOIN jogadores j ON p.id_jogador = j.id_jogador
ORDER BY p.data_partida ASC;

-----------------------------------

CREATE OR REPLACE FUNCTION fn_buscar_jogadores(p_termo VARCHAR)
RETURNS TABLE (
    id INT,
    nickname VARCHAR,
    email VARCHAR,
    ativo BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        j.id_jogador,
        j.nickname,
        j.email,
        j.ativo
    FROM jogadores j
    WHERE j.nickname ILIKE '%' || p_termo || '%'
       OR j.email ILIKE '%' || p_termo || '%';
END;
$$ LANGUAGE plpgsql;