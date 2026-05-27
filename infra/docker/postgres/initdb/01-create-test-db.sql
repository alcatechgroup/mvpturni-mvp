-- Banco de testes separado do banco de dev (turni). Os testes de integração
-- (CA-6) rodam contra PostgreSQL real, e RefreshDatabase recria o schema deste
-- banco a cada execução — por isso ele é isolado do banco de desenvolvimento.
-- Roda uma única vez, na inicialização do volume do Postgres.
CREATE DATABASE turni_test OWNER turni;
