<?php

namespace Tests\Feature;

use Tests\TestCase;

class DownloadPageTest extends TestCase
{
    public function test_download_page_returns_html_with_qr_and_apk_link(): void
    {
        $response = $this->get('/download');

        $response->assertOk();
        $this->assertStringContainsString('Unduh Siband APK', $response->getFile()->getContent());
        $this->assertStringContainsString('/download/siband.apk', $response->getFile()->getContent());
        $this->assertStringContainsString('id="qr-canvas"', $response->getFile()->getContent());
    }
}
