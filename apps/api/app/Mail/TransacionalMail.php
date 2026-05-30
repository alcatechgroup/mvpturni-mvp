<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Address;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;
use Turni\Domain\Email\EmailTransacional;
use Turni\Domain\Email\TipoEmail;

/**
 * Mailable único, parametrizado pelo VO de domínio (EmailTransacional).
 *
 * Mapeia cada TipoEmail (ADR-011 §d) para o conteúdo textual final do
 * SCREEN-STORY-021 §5 e renderiza o layout de tabela inline (HTML) + a paridade
 * text/plain — os dois templates consomem os MESMOS dados, garantindo paridade
 * (CA-10). Assunto vem de TipoEmail::assunto(); remetente de config('mail.from')
 * (ADR-011 §d — no-reply@mail.turni.com.br por ambiente).
 */
class TransacionalMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(public readonly EmailTransacional $email) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            from: new Address(
                (string) config('mail.from.address'),
                (string) config('mail.from.name'),
            ),
            subject: $this->email->tipo->assunto(),
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.transacional',
            text: 'emails.transacional-text',
            with: $this->conteudo(),
        );
    }

    /**
     * Conteúdo final por tipo (SCREEN-STORY-021 §5). Único lugar que conhece a
     * copy; HTML e text/plain consomem o mesmo array → paridade garantida.
     *
     * @return array<string, mixed>
     */
    private function conteudo(): array
    {
        $nome = $this->email->nome();
        $saudacao = $nome === null ? 'Olá.' : "Olá, {$nome}.";
        $dados = $this->email->dados;

        return match ($this->email->tipo) {
            TipoEmail::AprovacaoConcedida => [
                'preheader' => 'Seu cadastro foi aprovado. Acesse para finalizar e começar a usar o Turni.',
                'h1' => 'Cadastro aprovado',
                'saudacao' => $saudacao,
                'paragrafos' => [
                    'Seu cadastro no Turni foi aprovado. Você já pode acessar a plataforma.',
                    'O próximo passo é completar seu cadastro — leva poucos minutos e libera o uso completo.',
                ],
                'ctaLabel' => 'Acessar o Turni',
                'ctaUrl' => (string) ($dados['link_acesso'] ?? ''),
                'aviso' => null,
                'rodape' => 'Você recebeu este e-mail porque seu cadastro no Turni foi aprovado. Dúvidas: contato@turni.com.br · Política de privacidade.',
            ],
            TipoEmail::LembreteCompletarCadastro => [
                'preheader' => 'Falta completar seu cadastro para começar a usar o Turni.',
                'h1' => 'Falta completar seu cadastro',
                'saudacao' => $saudacao,
                'paragrafos' => [
                    'Seu cadastro no Turni está aprovado, mas ainda não foi finalizado.',
                    'Quando você completar, poderá usar a plataforma por inteiro. Leva poucos minutos.',
                ],
                'ctaLabel' => 'Completar cadastro',
                'ctaUrl' => (string) ($dados['link_completar'] ?? ''),
                'aviso' => null,
                'rodape' => 'Você recebeu este lembrete porque seu cadastro no Turni ainda não foi concluído. Se não quiser concluir agora, é só ignorar. Dúvidas: contato@turni.com.br · Política de privacidade.',
            ],
            TipoEmail::RecuperacaoSenha => [
                'preheader' => 'Recebemos um pedido para redefinir sua senha no Turni.',
                'h1' => 'Redefinir senha',
                'saudacao' => $saudacao,
                'paragrafos' => [
                    'Recebemos um pedido para redefinir a senha da sua conta no Turni.',
                    sprintf(
                        'Este link expira em %d minutos e só pode ser usado uma vez.',
                        (int) ($dados['expiracao_minutos'] ?? 60),
                    ),
                ],
                'ctaLabel' => 'Redefinir senha',
                'ctaUrl' => (string) ($dados['link_redefinicao'] ?? ''),
                'aviso' => 'Se você não pediu para redefinir sua senha, ignore este e-mail — sua senha continua a mesma.',
                'rodape' => 'Por segurança, o Turni nunca pede sua senha por e-mail. Dúvidas: contato@turni.com.br · Política de privacidade.',
            ],
        };
    }
}
