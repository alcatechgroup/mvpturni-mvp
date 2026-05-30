TURNI.

{{ $h1 }}

{{ $saudacao }}

@foreach ($paragrafos as $paragrafo)
{{ $paragrafo }}

@endforeach
{{ $ctaLabel }}: {{ $ctaUrl }}
@if ($aviso)

{{ $aviso }}
@endif

---
{{ $rodape }}
