--TABELAS
CREATE TABLE clientes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    gamer_tag VARCHAR(50)
);

CREATE TABLE jogos (
    id SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    plataforma VARCHAR(50) NOT NULL,
    preco DECIMAL(10, 2) NOT NULL,
    quantidade_estoque INT NOT NULL
);

CREATE TABLE vendas (
    id SERIAL PRIMARY KEY,
    cliente_id INT NOT NULL,
    data_venda TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valor_total DECIMAL(10, 2) DEFAULT 0.00,
    CONSTRAINT fk_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
);

CREATE TABLE itens_venda (
    id SERIAL PRIMARY KEY,
    venda_id INT NOT NULL,
    jogo_id INT NOT NULL,
    quantidade INT NOT NULL,
    preco_unitario DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_venda FOREIGN KEY (venda_id) REFERENCES vendas(id) ON DELETE CASCADE,
    CONSTRAINT fk_jogo FOREIGN KEY (jogo_id) REFERENCES jogos(id)
);

CREATE TABLE alertas_reposicao (
    id SERIAL PRIMARY KEY,
    jogo_id INT NOT NULL,
    mensagem TEXT NOT NULL,
    data_alerta TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--FUNCTION AUXILIAR
CREATE OR REPLACE FUNCTION calcular_desconto_gamer(
    p_cliente_id INT,
    p_valor_bruto DECIMAL(10, 2)
)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_total_compras INT;
    v_desconto DECIMAL(10, 2) := 0.00;
BEGIN
    SELECT COUNT(*) INTO v_total_compras FROM vendas WHERE cliente_id = p_cliente_id;
    IF v_total_compras >= 5 THEN
        v_desconto := p_valor_bruto * 0.15;
    ELSIF v_total_compras >= 2 THEN
        v_desconto := p_valor_bruto * 0.05;
    ELSE
        v_desconto := 0.00;
    END IF;
    RETURN v_desconto;
END;
$$ LANGUAGE plpgsql;

--PROCEDURE DE VENDA COM TRANSAÇÃO
CREATE OR REPLACE PROCEDURE realizar_venda_jogos(
    p_cliente_id INT,
    p_jogo_ids INT[],
    p_quantidades INT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_venda_id INT;
    v_jogo_id INT;
    v_qtd_comprada INT;
    v_estoque_atual INT;
    v_preco_unitario DECIMAL(10, 2);
    v_subtotal DECIMAL(10, 2) := 0.00;
    v_desconto DECIMAL(10, 2) := 0.00;
    v_total_final DECIMAL(10, 2) := 0.00;
    i INT;
BEGIN
    INSERT INTO vendas (cliente_id, valor_total) VALUES (p_cliente_id, 0.00) RETURNING id INTO v_venda_id;

    FOR i IN 1 .. array_length(p_jogo_ids, 1) LOOP
        v_jogo_id := p_jogo_ids[i];
        v_qtd_comprada := p_quantidades[i];

        SELECT preco, quantidade_estoque INTO v_preco_unitario, v_estoque_atual
        FROM jogos WHERE id = v_jogo_id FOR UPDATE;

        IF v_estoque_atual < v_qtd_comprada THEN
            RAISE EXCEPTION 'Estoque insuficiente para o Jogo ID %', v_jogo_id;
        END IF;

        INSERT INTO itens_venda (venda_id, jogo_id, quantidade, preco_unitario)
        VALUES (v_venda_id, v_jogo_id, v_qtd_comprada, v_preco_unitario);

        UPDATE jogos SET quantidade_estoque = quantidade_estoque - v_qtd_comprada WHERE id = v_jogo_id;
        v_subtotal := v_subtotal + (v_preco_unitario * v_qtd_comprada);
    END LOOP;

    v_desconto := calcular_desconto_gamer(p_cliente_id, v_subtotal);
    v_total_final := v_subtotal - v_desconto;

    UPDATE vendas SET valor_total = v_total_final WHERE id = v_venda_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE EXCEPTION 'Transação abortada: %', SQLERRM;
END;
$$;

--TRIGGER
CREATE OR REPLACE FUNCTION fn_verificar_estoque_critico()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantidade_estoque < 3 THEN
        INSERT INTO alertas_reposicao (jogo_id, mensagem)
        VALUES (NEW.id, 'ALERTA DE ESTOQUE: O jogo ID ' || NEW.id || ' está com estoque crítico! Restam ' || NEW.quantidade_estoque || ' unidades.');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_estoque_critico
AFTER UPDATE ON jogos
FOR EACH ROW
EXECUTE FUNCTION fn_verificar_estoque_critico();

--DADOS INICIAIS (CLIENTES)
INSERT INTO clientes (nome, email, gamer_tag) VALUES ('Nathan Drake', 'nathan@uncharted.com', 'Nate_Treasure');
INSERT INTO jogos (titulo, plataforma, preco, quantidade_estoque) VALUES ('EA FC 26', 'PS5', 350.00, 2);