<?php

// Mensagens de autenticação em pt-BR (STORY-016). Sem este arquivo, locale=pt_BR
// caía no fallback en e exibia "These credentials do not match our records.".
// 'failed' é genérico de propósito (sem leak de existência de e-mail — CA-7/CA-8).

return [
    'failed' => 'Credenciais inválidas. Verifique o e-mail e a senha.',
    'password' => 'A senha informada está incorreta.',
    'throttle' => 'Muitas tentativas de acesso. Tente novamente em :seconds segundos.',
];
