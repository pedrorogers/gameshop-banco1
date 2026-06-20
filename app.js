const { Pool } = require('pg');
const readline = require('readline-sync');


const pool = new Pool({
    user: 'postgres',       
    host: 'localhost',
    database: 'gameshop_db',  
    password: 'Devevery27',
    port: 5432,
});

async function cadastrarJogo() {
    console.log('\n--- CADASTRAR NOVO JOGO ---');
    const titulo = readline.question('Titulo do Jogo: ');
    const plataforma = readline.question('Plataforma (PS5/Xbox/PC/Switch): ');
    const preco = readline.questionFloat('Preco: R$ ');
    const estoque = readline.questionInt('Quantidade em Estoque: ');

    try {
        const res = await pool.query(
            'INSERT INTO jogos (titulo, plataforma, preco, quantidade_estoque) VALUES ($1, $2, $3, $4) RETURNING id;',
            [titulo, plataforma, preco, estoque]
        );
        console.log(`\n✅ Jogo cadastrado! ID: ${res.rows[0].id}`);
    } catch (err) {
        console.error('❌ Erro:', err.message);
    }
}

async function listarJogos() {
    console.log('\n--- ESTOQUE DE JOGOS ---');
    try {
        const res = await pool.query('SELECT * FROM jogos ORDER BY id;');
        if (res.rows.length === 0) return console.log('Nenhum jogo encontrado.');
        console.table(res.rows);
    } catch (err) {
        console.error('❌ Erro:', err.message);
    }
}

async function menuRealizarVenda() {
    console.log('\n--- REALIZAR VENDA ---');
    // Usando o ID 1, que é o 'Nathan Drake' que inserimos no script do banco
    const clienteId = readline.questionInt('ID do Cliente: ');
    
    const jogoIds = [];
    const quantidades = [];
    let continuar = true;

    while (continuar) {
        const jogoId = readline.questionInt('ID do Jogo que deseja comprar: ');
        const qtd = readline.questionInt('Quantidade: ');

        jogoIds.push(jogoId);
        quantidades.push(qtd);

        continuar = readline.keyInYNStrict('Adicionar mais um jogo ao carrinho? ');
    }

    try {
        console.log('\nEnviando dados...');
        await pool.query('CALL realizar_venda_jogos($1, $2, $3)', [clienteId, jogoIds, quantidades]);
        console.log('🎉 Operação concluída!');
    } catch (err) {
        console.log('\n❌ FALHA NA TRANSAÇÃO:');
        console.error(err.message);
    }
}

async function main() {
    let rodando = true;
    while (rodando) {
        console.log('\n=====================================');
        console.log('        GAME SHOP - A NOSTALGIA DOS JOGOS É AQUI!         ');
        console.log('=====================================');
        console.log('1.Cadastrar Jogo');
        console.log('2.Listar Jogos');
        console.log('3.Realizar Venda');
        console.log('4. Sair');
        console.log('=====================================');
        
        const opcao = readline.questionInt('Escolha uma opcao: ');

        switch (opcao) {
            case 1: await cadastrarJogo(); break;
            case 2: await listarJogos(); break;
            case 3: await menuRealizarVenda(); break;
            case 4: 
                console.log('\nEncerrando o sistema...');
                await pool.end();
                rodando = false;
                break;
            default: console.log('Opção inválida!');
        }
        if (rodando) readline.question('\nPressione ENTER para continuar...');
    }
}

main(); 