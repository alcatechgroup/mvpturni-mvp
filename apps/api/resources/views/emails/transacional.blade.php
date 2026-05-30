{{-- E-mail transacional Turni (SCREEN-STORY-021). Layout por <table> com estilo
     inline e literais de cor DDR-001 (SCREEN §3) — convenção de e-mail HTML, não
     do produto (SCREEN §Nota de plataforma). Dados vêm do TransacionalMail. --}}
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>{{ $h1 }}</title>
</head>
<body style="margin:0;padding:0;background:#F7F4EC;">
  {{-- Preheader oculto (SCREEN §5) --}}
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">{{ $preheader }}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F7F4EC;">
    <tr><td align="center" style="padding:24px;">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#FFFFFF;border:1px solid #E0DDD3;border-radius:12px;">
        <tr><td style="padding:32px 32px 0;">
          <span style="font-family:'Bebas Neue',Arial,sans-serif;font-weight:700;letter-spacing:.06em;font-size:26px;color:#00A868;">TURNI.</span>
        </td></tr>
        <tr><td style="padding:24px 32px 0;">
          <h1 style="margin:0;font-size:24px;line-height:28px;color:#0F1B2D;font-weight:600;font-family:'Inter',-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">{{ $h1 }}</h1>
        </td></tr>
        <tr><td style="padding:16px 32px 0;font-family:'Inter',-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
          <p style="margin:0 0 16px;font-size:16px;line-height:24px;color:#42504A;">{{ $saudacao }}</p>
          @foreach ($paragrafos as $paragrafo)
            <p style="margin:0 0 16px;font-size:16px;line-height:24px;color:#42504A;">{{ $paragrafo }}</p>
          @endforeach
        </td></tr>
        <tr><td style="padding:28px 32px 8px;">
          <table role="presentation" cellpadding="0" cellspacing="0"><tr>
            <td bgcolor="#2D5F3F" style="border-radius:8px;">
              <a href="{{ $ctaUrl }}" style="display:inline-block;padding:13px 26px;font-size:15px;font-weight:600;color:#FFFFFF;text-decoration:none;font-family:'Inter',-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">{{ $ctaLabel }}</a>
            </td>
          </tr></table>
        </td></tr>
        <tr><td style="padding:12px 32px {{ $aviso ? '16px' : '24px' }};font-family:'Inter',-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
          <p style="margin:0;font-size:13px;line-height:18px;color:#6F7C72;">Se o botão não funcionar, copie e cole este endereço no navegador:<br><span style="color:#42504A;">{{ $ctaUrl }}</span></p>
        </td></tr>
        @if ($aviso)
          <tr><td style="padding:0 32px 16px;font-family:'Inter',-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
            <p style="margin:0;font-size:14px;line-height:20px;color:#42504A;">{{ $aviso }}</p>
          </td></tr>
        @endif
        <tr><td style="padding:0 32px;"><hr style="border:none;border-top:1px solid #E0DDD3;margin:0;"></td></tr>
        <tr><td style="padding:16px 32px 28px;font-family:'Inter',-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
          <p style="margin:0;font-size:12px;line-height:18px;color:#6F7C72;">{{ $rodape }}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
