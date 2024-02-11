USE master;
GO

-- Alterar a senha do usuário sa para '123456' e desativar a política de senha
ALTER LOGIN sa WITH PASSWORD = '123456', CHECK_POLICY = OFF;
GO
