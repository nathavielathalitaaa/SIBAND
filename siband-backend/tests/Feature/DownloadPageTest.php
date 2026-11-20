<?php

namespace Tests\Feature;

use Tests\TestCase;

class DownloadPageTest extends TestCase
{
    public function test_landing_page_unifies_apk_qr_download_and_therapist_share_entry(): void
    {
        $response = $this->get('/');

        $response->assertOk();
        $html = $response->getFile()->getContent();
        $this->assertStringContainsString('Unduh Siband APK', $html);
        $this->assertStringContainsString('id="qr-canvas"', $html);
        $this->assertStringContainsString('/download/siband.apk', $html);
        $this->assertStringContainsString('/share', $html);
        $this->assertStringContainsString('Buka Halaman Rekap Terapis', $html);
    }

    public function test_download_page_returns_html_with_qr_and_apk_link(): void
    {
        $response = $this->get('/download');

        $response->assertOk();
        $this->assertStringContainsString('Unduh Siband APK', $response->getFile()->getContent());
        $this->assertStringContainsString('/download/siband.apk', $response->getFile()->getContent());
        $this->assertStringContainsString('id="qr-canvas"', $response->getFile()->getContent());
    }
}
