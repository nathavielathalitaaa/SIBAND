<?php

namespace Tests\Feature;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class SharePageGuardTest extends TestCase
{
    private function shareHtml(): string
    {
        $path = public_path('share.html');
        $this->assertFileExists($path);

        $content = file_get_contents($path);
        $this->assertIsString($content);

        return $content;
    }

    #[Test]
    public function share_page_preserves_exact_csp_and_security_headers(): void
    {
        $html = $this->shareHtml();

        $expectedCsp = '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; script-src \'unsafe-inline\'; connect-src \'self\'; img-src \'self\' data:; base-uri \'none\'; form-action \'none\'">';

        $this->assertStringContainsString($expectedCsp, $html);
        $this->assertStringContainsString('noindex', $html);
        $this->assertStringContainsString('no-referrer', $html);
    }

    #[Test]
    public function share_page_forbids_unsafe_dom_sinks_and_external_resources(): void
    {
        $html = $this->shareHtml();

        foreach (['innerHTML', 'outerHTML', 'insertAdjacentHTML', 'document.write', '@import'] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $html);
        }

        $this->assertDoesNotMatchRegularExpression('/\b(?:src|href)\s*=\s*["\']https?:\/\//i', $html);
        $this->assertDoesNotMatchRegularExpression('/<svg\b[^>]*\bxmlns\s*=/i', $html);
    }

    #[Test]
    public function share_page_includes_responsive_desktop_print_accessibility_and_safe_rendering(): void
    {
        $html = $this->shareHtml();

        $this->assertStringContainsString('lang="id"', $html);
        $this->assertStringContainsString('aria-live="polite"', $html);
        $this->assertStringContainsString('@media print', $html);
        $this->assertStringContainsString('min-width: 900px', $html);
        $this->assertStringContainsString('textContent', $html);
        $this->assertStringContainsString('Cetak / Simpan PDF', $html);
        $this->assertStringContainsString('Memuat data rekap...', $html);
        $this->assertStringContainsString('Tautan tidak ditemukan atau sudah tidak berlaku.', $html);
    }
}
